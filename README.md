# CoCo SPICE Releases

[`coco-spice`](https://github.com/penta-cube/coco-spice)의 검증된 실행 파일과 release
metadata를 배포하기 위한 저장소다.

## Release assets

| Platform | Architecture | Asset |
| --- | --- | --- |
| Windows | x64 | `coco-spice-windows-x64.exe` |
| macOS | Intel x64 | `coco-spice-macos-x64` |
| macOS | Apple Silicon | `coco-spice-macos-arm64` |
| Linux | x64 | `coco-spice-linux-x64` |

`.github/workflows/release.yml`의 수동 workflow에서 release tag와 `coco-spice` source ref를
지정하면 네 플랫폼에서 `cargo test --locked`와 release build를 수행한 뒤 위 asset과
`SHA256SUMS`를 이 저장소의 GitHub Release에 게시한다.

private source와 `coco-schematic-model` Git dependency를 checkout하기 위해 저장소 Actions
secret `COCO_RELEASES_TOKEN`이 필요하다. Token은 두 source 저장소에 대한 read 권한만 있으면
되며 release 생성은 workflow의 `GITHUB_TOKEN`으로 수행한다.
