[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CocoSpiceExecutable,

    [Parameter(Mandatory = $true)]
    [string]$NgspiceRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

$ngspiceVersion = "46"
$ngspiceArchiveName = "ngspice-46_64.7z"
$ngspiceArchiveSha256 = "7ed713cd8d401db724ffe99087c3122bf05a9cfa99de02c6eeed44ee44785a33"
$ngspiceSourceUrl = "https://sourceforge.net/projects/ngspice/files/ng-spice-rework/46/ngspice-46_64.7z/download"

$cocoSpicePath = (Resolve-Path -LiteralPath $CocoSpiceExecutable).Path
$ngspicePath = (Resolve-Path -LiteralPath $NgspiceRoot).Path
$noticesPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\THIRD-PARTY-NOTICES.txt")).Path
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)

$runtimeFiles = @(
    "bin\ngspice_con.exe",
    "bin\libomp140.x86_64.dll",
    "lib\ngspice\spice2poly.cm",
    "lib\ngspice\analog.cm",
    "lib\ngspice\digital.cm",
    "lib\ngspice\xtradev.cm",
    "lib\ngspice\xtraevt.cm",
    "lib\ngspice\table.cm",
    "lib\ngspice\tlines.cm",
    "share\ngspice\scripts\spinit",
    "docs\COPYING"
)

foreach ($relativePath in $runtimeFiles) {
    $sourcePath = Join-Path $ngspicePath $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "ngspice runtime file is missing: $relativePath"
    }
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$stagePath = Join-Path $outputPath (".coco-spice-windows-x64-" + [Guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $outputPath "coco-spice-windows-x64.zip"
$standalonePath = Join-Path $outputPath "coco-spice-windows-x64.exe"

try {
    New-Item -ItemType Directory -Path $stagePath | Out-Null
    Copy-Item -LiteralPath $cocoSpicePath -Destination (Join-Path $stagePath "coco-spice.exe")

    $enginePath = Join-Path $stagePath "engines\ngspice"
    foreach ($relativePath in $runtimeFiles) {
        $destinationRelativePath = if ($relativePath -eq "docs\COPYING") {
            "licenses\COPYING.ngspice"
        } else {
            $relativePath
        }
        $destinationPath = Join-Path $enginePath $destinationRelativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $ngspicePath $relativePath) -Destination $destinationPath
    }

    Copy-Item -LiteralPath $noticesPath -Destination (Join-Path $enginePath "licenses\THIRD-PARTY-NOTICES.txt")

    $manifestFiles = Get-ChildItem -LiteralPath $enginePath -Recurse -File |
        Where-Object { $_.Name -ne "engine-manifest.json" } |
        Sort-Object FullName |
        ForEach-Object {
            [ordered]@{
                relativePath = $_.FullName.Substring($enginePath.Length + 1).Replace("\", "/")
                bytes = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }

    $manifest = [ordered]@{
        schemaVersion = "1.0"
        engine = "ngspice"
        version = $ngspiceVersion
        source = [ordered]@{
            url = $ngspiceSourceUrl
            archiveName = $ngspiceArchiveName
            sha256 = $ngspiceArchiveSha256
        }
        executable = "bin/ngspice_con.exe"
        files = @($manifestFiles)
    }
    $manifestJson = ($manifest | ConvertTo-Json -Depth 6) + [Environment]::NewLine
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $enginePath "engine-manifest.json"),
        $manifestJson,
        $utf8WithoutBom
    )

    Copy-Item -LiteralPath $cocoSpicePath -Destination $standalonePath -Force
    Compress-Archive -Path (Join-Path $stagePath "*") -DestinationPath $archivePath -CompressionLevel Optimal -Force
} finally {
    if (Test-Path -LiteralPath $stagePath) {
        Remove-Item -LiteralPath $stagePath -Recurse -Force
    }
}

Write-Output "Standalone asset: $standalonePath"
Write-Output "Bundled asset: $archivePath"
