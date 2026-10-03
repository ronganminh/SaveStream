# SaveStream app icon

`AppIcon.png` and the other icon sizes in this folder are generated, not
committed. Run `bash tool/generate_native_assets.sh` from `apps/mobile` to
rasterize `assets/branding/savestream_mark.svg` and produce them before an iOS
build. CI runs the same generators before its native builds.
