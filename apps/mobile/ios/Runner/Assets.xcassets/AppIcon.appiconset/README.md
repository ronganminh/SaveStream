# SaveStream app icon

The committed `AppIcon.png` is the 1024×1024 raster release source derived from
SaveStream branding. Phase 17 validates it with `flutter_launcher_icons`, which
generates the required Android mipmap and iOS AppIcon raster sizes during the
release build.

Do not replace this file with an SVG renamed to `.png` or another undecodable
placeholder. CI deliberately runs the icon generator before native builds.
