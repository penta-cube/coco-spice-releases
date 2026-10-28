# CoCo SPICE Releases

[`coco-spice`](https://github.com/penta-cube/coco-spice)의 검증된 실행 파일과 release
metadata를 배포하기 위한 저장소다.

## Latest Release

- [v0.6.0](https://github.com/penta-cube/coco-spice-releases/releases/tag/v0.6.0) (2026-10-28)
- Source: [`53658750ab275989714266103371c544cc25da90`](https://github.com/penta-cube/coco-spice/commit/53658750ab275989714266103371c544cc25da90)
- Pinned schematic model: `1519b5799e576e0decc190c7225ad0abfde32481`.
- SUBCKT 단자 역할 분석, netlist 첫 줄 주석, PSpice 전압/핀 전류 alias 및 DC/Probe 파싱 개선 포함.
- 검증: Rust 176개 테스트, Windows release build, 단독/ZIP CLI help, ZIP ngspice 46 실제 시뮬레이션 통과.
- exe SHA-256: `07432194ff03389efe94095cad5f27fce24c928ab6808d4607e02b0c8e8d8ff9`.
- ZIP SHA-256: `8fe82aa202a557420abd88f8a53545549a0db42f1d889c97799bb9a0c2964f1d`.

## Release assets

| Platform | Architecture | Asset | Contents |
| --- | --- | --- | --- |
| Windows | x64 | `coco-spice-windows-x64.exe` | 기존 호환용 standalone CLI |
| Windows | x64 | `coco-spice-windows-x64.zip` | CLI와 bundled ngspice runtime |

v0.6.0부터 `coco-connect-hdl-releases`와 동일하게 로컬 Windows에서 검증한 실행 파일을
인증된 GitHub CLI로 게시한다. macOS/Linux asset은 v0.5.0까지의 이전 릴리스에서 제공한다.

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

ngspice 46 runtime은 기존 공식 v0.5.0 Windows ZIP을 SHA-256
`6e29d6795ccabd1ddb3d54d60109e8c3c40206e13ca0405cfb04f8b56a06c06a`로 고정해 재사용한다.
기존 CLI는 사용하지 않고 새 빌드로 교체하며 `scripts/package-windows.ps1`이 runtime
파일별 hash와 크기를 `engine-manifest.json`에 기록한다. 7-Zip 설치는 필요하지 않다.

## Release procedure

필수 환경: PowerShell, Rust/MSVC 빌드 도구, Git 및 인증된 `gh`, private source와
`coco-schematic-model` 접근 권한. Actions secret은 사용하지 않는다.

```powershell
# 인접 coco-spice checkout이 clean 상태이며 원격 main의 최신 커밋이어야 한다.
.\scripts\release-windows.ps1 -Tag v0.6.0
# 같은 검증·빌드 후 draft에 asset을 올리고 latest로 게시한다.
.\scripts\release-windows.ps1 -Tag v0.6.0 -Publish
```

스크립트는 기존 tag를 빌드 전에 거부한다. `cargo test --locked`, release build,
단독/ZIP CLI `--help`, ZIP에 포함된 ngspice 실제 시뮬레이션을 확인한다.
`dist/<tag>/`에 실행 파일, ZIP, `SHA256SUMS`, source SHA 및 검증 내역이 있는
release notes를 준비한다. 게시 전에 이 저장소의 배포 스크립트 변경을 commit/push한다.
실패한 draft가 있으면 원인을 확인하고 해당 draft에서 업로드/게시를 마무리한다.

## Local Windows packaging check

```powershell
.\scripts\package-windows.ps1 `
  -CocoSpiceExecutable ..\coco-spice\target\release\coco-spice.exe `
  -NgspiceRoot C:\path\to\ngspice-46_64\Spice64 `
  -OutputDirectory .\dist
```
