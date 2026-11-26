# Golden references

One exact reference per **host rasteriser**, because `flutter test` rasterises
glyphs with the host font backend (CoreText on macOS, FreeType on Linux). The
same widget tree legitimately differs by ~1.5% of its pixels between the two —
every one of those pixels sits inside a glyph or icon, and the ink bounding box
of each text band is identical, so it is antialiasing, not layout.

| file | produced by |
|---|---|
| `classic_light.macos.png`, `classic_dark.macos.png` | the macOS developer machine |
| `classic_light.linux.png`, `classic_dark.linux.png` | the Ubuntu CI runner (GitHub Actions) |

Regenerating (`flutter test --update-goldens`) writes **only** the current
platform's file, so a Linux refresh can never silently accept a macOS
regression, and vice versa.

A run without a reference for its platform fails on purpose and writes a
candidate to `test/failures/<name>.<platform>.candidate.png`. Review it visually
against the other platform's reference (same elements, same positions, ink
bounding boxes within a pixel) and only then rename it into `test/goldens/`.

There is no percentage tolerance anywhere: comparisons stay pixel exact.

## Refreshing a stale reference

`classic_dark.linux.png` was refreshed in phase 6.5 after the dark baseline had
drifted from two deliberate colour decisions that landed earlier (a white app
bar title/icon, and a solid accent fill darkened by `whiteForegroundSurface()`
to keep white ink at >= 4.5:1). The evidence, taken from the failing Ubuntu run:

| region | old master | current render |
|---|---|---|
| app bar title ink | `#ECEFF1` (theme text colour) | `#FFFFFF` |
| elevated button fill | `#389 68C` | `#31837A` |

Those are the only two flat colours that differ (13 620 + 4 800 px), plus 12
antialiased edge pixels; 6.86 % of the image in total, with no element moved,
resized or restyled. The macOS reference — generated from the same source and
passing — differs from this Linux render by 1.54 %, all of it glyph
antialiasing, which is the expected rasteriser delta described above.
