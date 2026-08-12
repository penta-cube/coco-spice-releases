# CoCo SPICE Releases

[`coco-spice`](https://github.com/penta-cube/coco-spice)의 검증된 실행 파일과 release
metadata를 배포하기 위한 저장소다.

## Release assets

| Platform | Architecture | Asset | Contents |
| --- | --- | --- | --- |
| Windows | x64 | `coco-spice-windows-x64.exe` | 기존 호환용 standalone CLI |
| Windows | x64 | `coco-spice-windows-x64.zip` | CLI와 bundled ngspice runtime |
| macOS | Intel x64 | `coco-spice-macos-x64` | standalone CLI |
| macOS | Apple Silicon | `coco-spice-macos-arm64` | standalone CLI |
| Linux | x64 | `coco-spice-linux-x64` | standalone CLI |

Windows ZIP은 다음 구조를 사용한다.

```text
coco-spice.exe
engines/ngspice/
├── engine-manifest.json
├── bin/
│   ├── ngspice_con.exe
│   └── libomp140.x86_64.dll
├── lib/ngspice/
│   ├── spice2poly.cm
│   ├── analog.cm
│   ├── digital.cm
│   ├── xtradev.cm
│   ├── xtraevt.cm
│   ├── table.cm
│   └── tlines.cm
├── share/ngspice/scripts/spinit
└── licenses/
    ├── COPYING.ngspice
    └── THIRD-PARTY-NOTICES.txt
```

ngspice runtime은 공식 `ngspice-46_64.7z`를 SHA-256으로 pin한다. workflow는
archive를 검증한 뒤 `scripts/package-windows.ps1`로 필요한 runtime 파일만 선별하고,
각 파일의 hash와 크기를 `engine-manifest.json`에 기록한다.

`.github/workflows/release.yml`의 수동 workflow에서 release tag와 `coco-spice` source
ref를 지정하면 네 플랫폼에서 `cargo test --locked`와 release build를 수행한 뒤 위
asset과 `SHA256SUMS`를 이 저장소의 GitHub Release에 게시한다.

private source와 `coco-schematic-model` Git dependency를 checkout하기 위해 저장소
Actions secret `COCO_RELEASES_TOKEN`이 필요하다. Token은 source 저장소 read 권한만
있으면 되며 release 생성은 workflow의 `GITHUB_TOKEN`으로 수행한다.

## Local Windows packaging check

```powershell
.\scripts\package-windows.ps1 `
  -CocoSpiceExecutable ..\coco-spice\target\release\coco-spice.exe `
  -NgspiceRoot C:\path\to\ngspice-46_64\Spice64 `
  -OutputDirectory .\dist
```
