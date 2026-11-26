import 'dart:convert';

import '../../core/database/app_database.dart';
import 'sync_provider.dart';

/// Remembers **proven** capabilities per sync target.
///
/// A full WebDAV probe costs roughly a dozen round trips (PROPFIND, PUT, GET,
/// conditional PUTs, DELETE). MaterialWord syncs on start-up, on resume, after
/// edits and after a study round, so probing every time would be slow, wasteful
/// and — on commercial services — a good way to get rate limited.
///
/// The cache is bound to a fingerprint of the *target* (normalised address,
/// directory, file name, credential epoch, user-name digest). Anything that can
/// change what the server allows invalidates it automatically; the TTL covers
/// server-side policy changes that this device cannot observe.
///
/// Only successful, fully verified results are stored. A failure is never
/// cached, so a server that was broken five minutes ago is re-probed.
class SyncCapabilityCache {
  SyncCapabilityCache(this.db, {this.ttl = const Duration(days: 7)});

  final AppDatabase db;

  /// How long a verified capability may be trusted without re-probing.
  Duration ttl;

  /// Bumped when the meaning of a stored capability changes.
  static const String version = '2';

  static const String _prefix = 'sync_capability:';

  static String keyFor(String targetKey) => '$_prefix$targetKey';

  Future<SyncCapability?> read({
    required String targetKey,
    required String fingerprint,
    DateTime? now,
  }) async {
    final String? raw = await db.readMeta(keyFor(targetKey));
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['v'] != version) return null;
    if (decoded['fingerprint'] != fingerprint) return null;
    final DateTime? at = DateTime.tryParse(decoded['at'] as String? ?? '');
    if (at == null) return null;
    final DateTime reference = now ?? DateTime.now();
    if (reference.difference(at) > ttl) return null;
    return SyncCapability.fromJson(decoded['capability']);
  }

  Future<void> write({
    required String targetKey,
    required String fingerprint,
    required SyncCapability capability,
    DateTime? now,
  }) async {
    if (!capability.safeBidirectionalSync) return;
    await db.writeMeta(
      keyFor(targetKey),
      jsonEncode(<String, Object?>{
        'v': version,
        'at': (now ?? DateTime.now()).toUtc().toIso8601String(),
        'fingerprint': fingerprint,
        'capability': capability.toJson(),
      }),
    );
  }

  Future<void> clear(String targetKey) => db.deleteMeta(keyFor(targetKey));
}
