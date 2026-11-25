import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'support/platform_golden_comparator.dart';

/// Guards the platform-aware golden resolution: an exact per-rasteriser
/// reference, no percentage tolerance, and regeneration that never overwrites
/// another platform's baseline.
class _RecordingComparator extends PlatformGoldenFileComparator {
  _RecordingComparator(super.testFile);

  Uri? chosen;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    chosen = resolveReference(golden);
    return true;
  }
}

void main() {
  test('variant URI keeps the directory and extension', () {
    expect(
      PlatformGoldenFileComparator.variantUri(
        Uri.parse('goldens/classic_light.png'),
        'linux',
      ).path,
      'goldens/classic_light.linux.png',
    );
    expect(
      PlatformGoldenFileComparator.variantUri(
        Uri.parse('goldens/nested/name.with.dots.png'),
        'macos',
      ).path,
      'goldens/nested/name.with.dots.macos.png',
    );
    // No extension: append the tag instead of corrupting the name.
    expect(
      PlatformGoldenFileComparator.variantUri(
        Uri.parse('goldens/plain'),
        'linux',
      ).path,
      'goldens/plain.linux',
    );
  });

  test('exact platform reference wins, shared file is the fallback', () async {
    final Directory dir = Directory.systemTemp.createTempSync('mw_golden_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/goldens').createSync();
    final Uri golden = Uri.parse('goldens/case.png');
    final String tag = PlatformGoldenFileComparator.platformTag;
    final File shared = File('${dir.path}/goldens/case.png')
      ..writeAsBytesSync(<int>[1, 2, 3]);
    final File variant = File('${dir.path}/goldens/case.$tag.png');
    final _RecordingComparator comparator = _RecordingComparator(
      Uri.file('${dir.path}/sample_test.dart'),
    );

    // No platform reference yet: the shared image is used. A mismatch is still
    // a hard failure — there is no tolerance anywhere in the comparator.
    expect(comparator.hasVariant(golden), isFalse);
    expect(await comparator.compare(Uint8List(0), golden), isTrue);
    expect(comparator.chosen?.path, 'goldens/case.png');

    // Once a platform reference exists it wins over the shared image.
    variant.writeAsBytesSync(<int>[4, 5, 6]);
    expect(comparator.hasVariant(golden), isTrue);
    await comparator.compare(Uint8List(0), golden);
    expect(comparator.chosen?.path, 'goldens/case.$tag.png');

    // Regeneration writes the platform file only.
    await comparator.update(golden, Uint8List.fromList(<int>[7, 8, 9]));
    expect(variant.readAsBytesSync(), <int>[7, 8, 9]);
    expect(shared.readAsBytesSync(), <int>[1, 2, 3]);
  });
}
