import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exact-match golden comparator that resolves a per-platform reference image
/// before falling back to the shared one.
///
/// Why this exists: golden files produced by `flutter test` are rasterised by
/// the host's Skia font backend. macOS renders glyph edges through CoreText,
/// Linux through FreeType, so the *same* widget tree legitimately produces a
/// few thousand antialiased edge pixels of difference between the developer
/// machine and the Ubuntu CI runner. That is a property of the rasteriser, not
/// of the UI — but it is still an exact comparison on each platform, so a real
/// layout, colour or shape regression keeps failing on both.
///
/// Resolution order for `goldens/classic_light.png`:
///   1. `goldens/classic_light.<platform>.png` (macos / linux / windows)
///   2. `goldens/classic_light.png`
///
/// `flutter test --update-goldens` always writes the platform-specific file, so
/// regenerating a reference never overwrites another platform's baseline.
///
/// There is deliberately no percentage tolerance here: the reference images
/// stay pixel-exact, and every new reference must be reviewed visually before
/// it is committed.
class PlatformGoldenFileComparator extends LocalFileComparator {
  PlatformGoldenFileComparator(super.testFile);

  /// `macos`, `linux`, `windows`, … — the rasteriser family, not the target
  /// platform the app is compiled for.
  static String get platformTag {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    return Platform.operatingSystem;
  }

  /// `goldens/name.png` → `goldens/name.linux.png`
  @visibleForTesting
  static Uri variantUri(Uri golden, String platform) {
    final String path = golden.path;
    final int slash = path.lastIndexOf('/');
    final int dot = path.lastIndexOf('.');
    if (dot <= slash) return Uri.parse('$path.$platform');
    return Uri.parse(
      '${path.substring(0, dot)}.$platform${path.substring(dot)}',
    );
  }

  File _fileFor(Uri golden) => File.fromUri(basedir.resolveUri(golden));

  bool hasVariant(Uri golden) =>
      _fileFor(variantUri(golden, platformTag)).existsSync();

  /// The reference image actually used for [golden] on this host.
  Uri resolveReference(Uri golden) =>
      hasVariant(golden) ? variantUri(golden, platformTag) : golden;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) {
    return super.compare(imageBytes, resolveReference(golden));
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    return super.update(variantUri(golden, platformTag), imageBytes);
  }
}
