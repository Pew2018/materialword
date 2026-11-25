import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/services/sync/webdav_paths.dart';

void main() {
  test(
    'DAV-R01 through R04 base URI preserves trailing slash without query',
    () {
      final WebDavPaths paths = WebDavPaths.resolve(
        baseUrl: 'https://dav.jianguoyun.com/dav/',
        remoteDir: '',
        fileName: 'materialword-data.json',
      )!;
      expect(paths.base.toString(), 'https://dav.jianguoyun.com/dav/');
      expect(paths.base.hasQuery, isFalse);
      expect(paths.base.hasFragment, isFalse);
      expect(paths.directoryUri.toString(), 'https://dav.jianguoyun.com/dav/');
      expect(
        paths.fileUri.toString(),
        'https://dav.jianguoyun.com/dav/materialword-data.json',
      );
    },
  );

  test('DAV-R04 paths encode once and remain under the base collection', () {
    for (final String name in <String>[
      'MaterialWord',
      '/MaterialWord',
      '/MaterialWord/',
      'Material%20Word',
      '中文目录',
      '空格 目录',
    ]) {
      final WebDavPaths paths = WebDavPaths.resolve(
        baseUrl: 'https://dav.jianguoyun.com/dav/',
        remoteDir: name,
        fileName: 'materialword-data.json',
      )!;
      expect(paths.directoryUri.hasQuery, isFalse);
      expect(paths.directoryUri.hasFragment, isFalse);
      expect(paths.directoryUri.path, startsWith('/dav/'));
      expect(paths.directoryUri.toString(), isNot(contains('%2520')));
      expect(paths.directoryUri.toString(), isNot(contains('//dav')));
    }
  });
}
