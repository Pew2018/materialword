import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/app/app_info.dart';

void main() {
  test('dictionaryEntryCount matches ecdict_core.db.meta.json entries', () {
    final File meta = File('assets/dictionary/ecdict_core.db.meta.json');
    expect(meta.existsSync(), isTrue);
    final Object? decoded = jsonDecode(meta.readAsStringSync());
    expect(decoded, isA<Map<String, Object?>>());
    final Map<String, Object?> json = decoded! as Map<String, Object?>;
    expect(json['entries'], dictionaryEntryCount);
  });
}
