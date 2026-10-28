[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+$')]
    [string]$Tag,
    [string]$SourceDirectory = (Join-Path $PSScriptRoot '..\..\coco-spice'),
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed (exit $LASTEXITCODE)." }
}

$repo = 'penta-cube/coco-spice-releases'
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$releaseRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$out = Join-Path $releaseRoot "dist\$Tag"
# Check credentials, source provenance, and tag availability before compiling.
Invoke-Checked gh @('auth', 'status')
$sourceSha = (Invoke-Checked git @('-C', $source, 'rev-parse', 'HEAD')).Trim()
$mainSha = (Invoke-Checked gh @('api', 'repos/penta-cube/coco-spice/commits/main', '--jq', '.sha')).Trim()
if ($sourceSha -ne $mainSha) { throw "Source HEAD $sourceSha differs from remote main $mainSha." }
$dirty = Invoke-Checked git @('-C', $source, 'status', '--porcelain', '--untracked-files=all')
if ($dirty) { throw 'Source must be clean, including untracked files.' }
$tags = @(Invoke-Checked gh @('api', "repos/$repo/releases", '--paginate', '--jq', '.[].tag_name'))
$gitTags = @(Invoke-Checked gh @('api', "repos/$repo/git/matching-refs/tags/$Tag", '--jq', '.[].ref'))
if ($tags -contains $Tag -or $gitTags -contains "refs/tags/$Tag") { throw "Tag $Tag already exists." }
New-Item -ItemType Directory -Path $out -Force | Out-Null

Invoke-Checked cargo @('test', '--locked', '--target', 'x86_64-pc-windows-msvc', '--manifest-path', (Join-Path $source 'Cargo.toml'))
Invoke-Checked cargo @('build', '--release', '--locked', '--target', 'x86_64-pc-windows-msvc', '--manifest-path', (Join-Path $source 'Cargo.toml'))
$exe = Join-Path $source 'target\x86_64-pc-windows-msvc\release\coco-spice.exe'
Invoke-Checked $exe @('--help')

# Reuse only the verified ngspice 46 runtime from the previous official bundle.
# Its CLI is discarded; package-windows.ps1 always inserts the new executable.
$runtimeZip = Join-Path $out 'runtime-v0.5.0.zip'
Invoke-Checked gh @('release', 'download', 'v0.5.0', '--repo', $repo, '--pattern', 'coco-spice-windows-x64.zip', '--output', $runtimeZip, '--clobber')
$expected = '6e29d6795ccabd1ddb3d54d60109e8c3c40206e13ca0405cfb04f8b56a06c06a'
if ((Get-FileHash -LiteralPath $runtimeZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Pinned runtime bundle checksum mismatch.'
}
$runtimeDir = Join-Path $out ('runtime-' + [Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $runtimeZip -DestinationPath $runtimeDir
$engine = Join-Path $runtimeDir 'engines\ngspice'
New-Item -ItemType Directory -Path (Join-Path $engine 'docs') | Out-Null
Copy-Item -LiteralPath (Join-Path $engine 'licenses\COPYING.ngspice') -Destination (Join-Path $engine 'docs\COPYING')
& (Join-Path $PSScriptRoot 'package-windows.ps1') -CocoSpiceExecutable $exe -NgspiceRoot $engine -OutputDirectory $out

$smoke = Join-Path $out ('smoke-' + [Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath (Join-Path $out 'coco-spice-windows-x64.zip') -DestinationPath $smoke
Copy-Item -LiteralPath (Join-Path $source 'fixtures\minimal.ngspice.cir') -Destination (Join-Path $smoke 'circuit.ngspice.cir')
Push-Location $smoke
try {
    Invoke-Checked '.\coco-spice.exe' @('--help')
    Invoke-Checked '.\engines\ngspice\bin\ngspice_con.exe' @('-n', '-b', '-o', 'ngspice.log', '-r', 'simulation.raw', 'circuit.ngspice.cir')
    if (-not (Test-Path -LiteralPath 'simulation.raw')) { throw 'ngspice did not create simulation.raw.' }
    if (Select-String -LiteralPath 'ngspice.log' -Pattern 'warning|error|can.t find') { throw 'ngspice reported warnings or errors.' }
} finally { Pop-Location }

$assets = @('coco-spice-windows-x64.exe', 'coco-spice-windows-x64.zip')
$checksums = foreach ($name in $assets) {
    '{0}  {1}' -f (Get-FileHash -LiteralPath (Join-Path $out $name) -Algorithm SHA256).Hash.ToLowerInvariant(), $name
}
$checksums | Set-Content -LiteralPath (Join-Path $out 'SHA256SUMS') -Encoding utf8
$notes = @"
Source: https://github.com/penta-cube/coco-spice/commit/$sourceSha

Source history: https://github.com/penta-cube/coco-spice/commits/$sourceSha

Validation: cargo test --locked; cargo build --release --locked; standalone and bundled CLI --help; bundled ngspice 46 simulation smoke check.

Built and published locally using the authenticated GitHub CLI, matching coco-connect-hdl. Windows x64 assets only for this release.

SHA-256:
$($checksums -join "`n")
"@
$notesPath = Join-Path $out 'release-notes.md'
$notes | Set-Content -LiteralPath $notesPath -Encoding utf8
Write-Output "Prepared $Tag from $sourceSha in $out"
if ($Publish) {
    # Keep incomplete uploads out of the latest release until all assets exist.
    $argsList = @('release', 'create', $Tag, '--repo', $repo, '--draft', '--title', "coco-spice $Tag", '--notes-file', $notesPath)
    $argsList += @($assets + 'SHA256SUMS' | ForEach-Object { Join-Path $out $_ })
    Invoke-Checked gh $argsList
    Invoke-Checked gh @('release', 'edit', $Tag, '--repo', $repo, '--draft=false', '--latest')
    Invoke-Checked gh @('release', 'view', $Tag, '--repo', $repo, '--json', 'url,tagName,assets,isDraft')
}
