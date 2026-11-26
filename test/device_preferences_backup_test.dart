import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:materialword/core/models/enums.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every export excludes device preferences and old restores ignore them',
    () async {
      final env = await TestEnv.create();
      addTearDown(env.dispose);
      await env.seedBook();
      await env.settings.save(
        theme: ThemePreference.dark,
        accentColor: '#123456',
        ttsVoice: 'private-voice',
        ttsLocale: 'private-locale',
        ttsRate: 75,
        ttsAutoSpeak: true,
      );
      await env.db.writeMeta('keep_screen_on', '1');
      final before = await env.settings.load();
      for (final include in [false, true]) {
        final data = await env.backup.buildDataset(
          now: env.clock.now(),
          includeDeviceSettings: include,
        );
        for (final key in [
          'deviceSettings',
          'themeMode',
          'accentColor',
          'ttsVoice',
          'ttsLocale',
          'ttsRate',
          'ttsAutoSpeak',
          'keepScreenOn',
        ]) {
          expect(jsonEncode(data), isNot(contains('"$key"')));
        }
      }
      final legacy = await env.backup.buildDataset(now: env.clock.now());
      legacy['schemaVersion'] = 4;
      legacy['deviceSettings'] = {
        'themeMode': 'light',
        'accentColor': '#FFFFFF',
        'ttsVoice': 'other',
        'ttsLocale': 'other',
        'ttsRate': 1,
        'ttsAutoSpeak': false,
        'keepScreenOn': false,
      };
      final file = File('${env.backupDirectory.path}/legacy.json');
      await file.writeAsString(jsonEncode(legacy));
      await env.backups.restoreMerge(file);
      await env.backups.restoreSnapshot(file, applyDeviceSettings: true);
      final after = await env.settings.load();
      expect(after.themeMode, before.themeMode);
      expect(after.accentColor, before.accentColor);
      expect(after.ttsVoice, before.ttsVoice);
      expect(after.ttsLocale, before.ttsLocale);
      expect(after.ttsRate, before.ttsRate);
      expect(after.ttsAutoSpeak, before.ttsAutoSpeak);
      expect(await env.db.readMeta('keep_screen_on'), '1');
    },
  );
}
