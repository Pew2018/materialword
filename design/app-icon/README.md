# MaterialWord app icon

Rebuilt as editable vector paths from the approved two-card design. The reference
presentation is not embedded, cropped, traced as a bitmap, or needed at build time.

## Design

All sources use a 1024 × 1024 viewBox. `master.svg` contains named background,
rear-card, front-card, shadows, letter and underline groups. `foreground.svg` omits
the background; `background.svg` is opaque and full bleed. `monochrome.svg` has
solid separated card silhouettes and genuinely transparent A / underline cutouts.
The triangular counter of the A remains a filled island. No fonts are required.

- Brand blue: #1565C0. Background diagonal: #249AF2 → #1565C0 → #0645A8.
- Front paper: #FFFFFF → #EDF5FF. Rear paper: #A5D9FF → #74BAEF (around #90CAF9).
- Letter and underline: #0863C7, always fixed independent of app accent settings.
- Front: x=220, y=205, width=470, height=570, corner radius=70; aspect 0.825.
- Rear: x=325, y=285, width=450, height=560, radius=65, 8° clockwise about (550,565).
- Both cards are translated up 16 units for optical centering. Front stays upright.
- A is a custom even-odd path, not a font glyph. Underline is 292 × 34 units.
- Low-opacity blue shadow paths preserve modest depth without SVG filters.
- Android applies a separate 0.72 optical scale about the canvas center; it does
  not reuse the unscaled Apple image as an adaptive foreground.
- Traditional macOS output maps the design into an 896 × 896 rounded tile at
  (64,64), with transparent margins (6.25% per edge). iOS keeps the full square.

## Generation

Python 3.9+, CairoSVG 2.8.2, Pillow 11.3.0, and the system Cairo library are needed
only by maintainers regenerating icons. They are not Flutter/runtime dependencies.
Use an isolated environment outside the repository, for example:

```sh
python3 -m venv ../icon-venv
../icon-venv/bin/pip install CairoSVG==2.8.2 Pillow==11.3.0
# macOS Homebrew Cairo discovery, if needed:
export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib
../icon-venv/bin/python tool/generate_app_icons.py
../icon-venv/bin/python tool/generate_app_icons.py --check
```

On Linux install/use the existing system libcairo. No Xcode/SDK upgrade is required.
Every PNG is independently rasterized from vector paths at 4× its target size and
antialiased down to that target. An embedded sRGB ICC profile identifies the color
space. iOS images are RGB; macOS and Android foreground images are RGBA. Commit all
outputs; ordinary builds need no Python generation step. Edit SVG source geometry
and then regenerate, keeping master/foreground/monochrome semantics consistent.

## Resource matrix and integration

| Platform | Outputs | Native integration |
| --- | --- | --- |
| Android legacy | 48, 72, 96, 144, 192px | Existing mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/ic_launcher.png |
| Android foreground | Transparent 108, 162, 216, 324, 432px | drawable-{density}/ic_launcher_foreground.png; 108dp layer canvas |
| Android background | Opaque gradient shape | drawable/ic_launcher_background.xml |
| Android monochrome | 108dp VectorDrawable, evenOdd holes | drawable/ic_launcher_monochrome.xml |
| Android API 26–32 | Two independent layers | mipmap-anydpi-v26/ic_launcher.xml |
| Android API 33+ | Two layers + monochrome | mipmap-anydpi-v33/ic_launcher.xml |
| iOS | 19 existing catalog entries / 15 unique PNGs, 20–1024px | Existing AppIcon.appiconset and unchanged Contents.json |
| macOS | 10 existing entries / 7 unique PNGs, 16–1024px | Existing AppIcon.appiconset and unchanged Contents.json |

The manifest has one `@mipmap/ic_launcher` reference, no roundIcon or activity/alias
icon override. No flavor/debug launcher overrides, launcher generator config,
referenced .icns, or additional app icon source was found. Round launcher masks use
the adaptive icon; no redundant round fallback is introduced. Current Flutter
3.50.1 uses compileSdk 36 / minSdk 24; the project still inherits these unchanged.
The v33 override keeps the monochrome tag out of older adaptive definitions.
Both Xcode projects already select `AppIcon`. No project setting changes needed.

Icon Composer and Apple dark/clear/tinted variants are not registered: the current
PNG catalogs remain the sole build input. Layered SVGs are supplied for future
work, with no fabricated .icon project or new build requirement.

## Preview and acceptance

`preview.png` displays generated Apple PNGs at large sizes, small vector-derived
probes at 16/24/32/48/64px, actual Android foreground PNG / monochrome VectorDrawable
geometry under simulated circle, rounded-square and squircle masks, three theme
colors, and the 66dp safety circle. Small probes at sizes not in the catalog are
explicit preview renders, not additional native assets. The Android simulation
crops the central 72dp launcher viewport before applying a mask. The background
simulation reads the generated gradient XML. These are simulations, not screenshots
from a launcher, Home Screen, Dock or Finder.

`--check` validates every catalog entry, PNG size, iOS RGB/no-alpha, macOS transparent
corners, ICC presence, Android density sizes and foreground alpha, XML syntax and
layer references, true monochrome cutouts, and the opaque foreground/monochrome
geometry inside the 66dp center circle. Opaque geometry reaches about 30.87dp and
31.17dp respectively, below the 33dp radius. No full Flutter test suite, simulator,
or newly installed native toolchain is needed for these checks. Native build and
artifact status is recorded in the delivery report separately from visual checks.

Reference specifications:
- [Android adaptive icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)
- [Apple app icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
- [Apple Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
