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
