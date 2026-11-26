part of 'webdav_sync_provider.dart';

/// A publisher owns a random name and only ever sends the same bytes to it.
/// The completion entry becomes visible after the data was read back.
class WebDavSnapshotStore {
  WebDavSnapshotStore(this.provider);

  final WebDavSyncProvider provider;

  static final RegExp _markerPattern = RegExp(
    r'^done-([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})-([0-9a-f]{64})\.v1$',
  );

  // Leaves room below Nutstore's single-list limit, including racing uploads.
  static const int _listingLimit = 650;
  static const int _publicationLimit = 600;

  Uri get _directory {
    final WebDavPaths? paths = provider.paths;
    if (paths == null || !provider.isSecure) {
      throw const SyncException('请配置有效的 HTTPS WebDAV 地址');
    }
    final String namespace = sha256
        .convert(utf8.encode(paths.fileUri.pathSegments.last))
        .toString()
        .substring(0, 16);
    final String relative = paths.relativePathOf(paths.directoryUri)!;
    return paths.collectionForPath(
      [
        if (relative.isNotEmpty) relative,
        'materialword-sync-v2-$namespace',
      ].join('/'),
    )!;
  }

  static final RegExp _shardName = RegExp(r'^objects-[0-9a-f]$');

  Uri _child(Uri directory, String name, {bool collection = false}) =>
      directory.replace(path: '${directory.path}$name${collection ? '/' : ''}');

  Uri _shard(String id) =>
      _child(_directory, 'objects-${id[0]}', collection: true);

  Future<http.Response> _request(
    String method,
    Uri uri, {
    List<int>? bytes,
  }) async {
    final http.Response response = await provider._send(
      method,
      uri,
      headers: await provider._headers(
        extra: {
          'Cache-Control': 'no-cache',
          if (bytes != null) 'Content-Type': 'application/octet-stream',
        },
      ),
      body: bytes,
      stage: WebDavStage.snapshotTransfer,
    );
    if (response.request?.url != uri) {
      throw const SyncException('快照服务器改变了请求目标');
    }
    return response;
  }

  Never _raise(http.Response response, String method) => provider._raise(
    response,
    '访问同步快照',
    stage: WebDavStage.snapshotTransfer,
    method: method,
  );

  Future<List<WebDavDirectoryEntry>> _listDirectory(
    Uri directory, {
    bool create = false,
  }) async {
    Future<http.Response> find() => provider._sendPropfind(
      directory,
      depth: '1',
      profile: WebDavPropfindProfile.directoryListing,
      stage: WebDavStage.snapshotTransfer,
    );
    http.Response response = await find();
    if (response.statusCode == 404 && create) {
      final http.Response created = await _request('MKCOL', directory);
      if (!WebDavSyncProvider._isSuccess(created.statusCode) &&
          created.statusCode != 405) {
        _raise(created, 'MKCOL');
      }
      response = await find();
    }
    if (response.statusCode == 404 && !create) return [];
    if (response.statusCode != 207 && response.statusCode != 200) {
      _raise(response, 'PROPFIND');
    }
    if (response.request?.url != directory ||
        response.headers['link'] != null ||
        response.headers['content-range'] != null) {
      throw const SyncDataException('无法确认已列出完整的同步快照目录');
    }
    final List<WebDavDirectoryEntry> entries = provider._parseMultistatus(
      WebDavSyncProvider._multistatusBody(response),
      directory,
    );
    if (entries.length >= _listingLimit ||
        !entries.any((entry) => entry.uri == directory && entry.isCollection)) {
      throw const SyncDataException('无法确认已列出完整的同步快照目录');
    }
    return entries;
  }

  Future<Map<String, String>> list() async {
    final Uri root = _directory;
    final List<WebDavDirectoryEntry> index = await _listDirectory(root);
    final Map<String, String> snapshots = {};
    final Set<Uri> shards = {};
    for (final WebDavDirectoryEntry entry in index) {
      if (!entry.isCollection) continue;
      final String name =
          entry.uri.pathSegments.where((part) => part.isNotEmpty).lastOrNull ??
          '';
      if (_shardName.hasMatch(name) &&
          entry.uri == _child(root, name, collection: true)) {
        shards.add(entry.uri);
      }
    }
    for (final Uri shard in shards) {
      final List<WebDavDirectoryEntry> entries = await _listDirectory(shard);
      if (entries.isEmpty) {
        throw const SyncException('同步快照分区暂时不可见', retryable: true);
      }
      for (final WebDavDirectoryEntry entry in entries) {
        if (entry.isCollection || entry.uri.pathSegments.isEmpty) continue;
        final String name = entry.uri.pathSegments.last;
        if (!name.startsWith('done-') || entry.uri != _child(shard, name)) {
          continue;
        }
        final RegExpMatch? marker = _markerPattern.firstMatch(name);
        if (marker == null || _shard(marker[1]!) != shard) {
          throw const SyncDataException('远端同步快照版本或路径不受支持');
        }
        final String id = marker[1]!;
        final String digest = marker[2]!;
        if (snapshots.containsKey(id) && snapshots[id] != digest) {
          throw const SyncDataException('同步快照编号重复，内容不一致');
        }
        snapshots[id] = digest;
      }
    }
    return snapshots;
  }

  Future<List<int>?> _read(Uri resource) async {
    final http.Response response = await _request('GET', resource);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _raise(response, 'GET');
    return response.bodyBytes;
  }

  Future<void> _writeOwned(Uri resource, List<int> bytes) async {
    final Digest expected = sha256.convert(bytes);
    final List<int>? before = await _read(resource);
    if (before != null) {
      if (sha256.convert(before) != expected) {
        throw const SyncDataException('同步快照内容发生意外变化');
      }
      return;
    }
    final http.Response response = await _request(
      'PUT',
      resource,
      bytes: bytes,
    );
    if (!WebDavSyncProvider._isSuccess(response.statusCode)) {
      _raise(response, 'PUT');
    }
    final List<int>? after = await _read(resource);
    if (after == null || sha256.convert(after) != expected) {
      throw const SyncException('暂时无法验证同步快照的内容', retryable: true);
    }
  }

  Future<void> verifyAccess() async {
    final Uri root = _directory;
    await _listDirectory(root, create: true);
    final String id = const Uuid().v4();
    final Uri shard = _shard(id);
    await _listDirectory(shard, create: true);
    final String name = 'snapshot-probe-$id';
    final Uri resource = _child(shard, name);
    try {
      await _writeOwned(resource, utf8.encode(name));
      final index = await _listDirectory(root);
      final entries = await _listDirectory(shard);
      if (!index.any((entry) => entry.uri == shard && entry.isCollection) ||
          !entries.any(
            (entry) => entry.uri == resource && !entry.isCollection,
          )) {
        throw const SyncException('同步快照写入后在目录中不可见', retryable: true);
      }
    } finally {
      final http.Response deleted = await _request('DELETE', resource);
      if (!WebDavSyncProvider._isSuccess(deleted.statusCode) &&
          deleted.statusCode != 404) {
        _raise(deleted, 'DELETE');
      }
    }
  }

  Future<Map<String, Object?>> fetch(String id, String digest) async {
    final List<int>? bytes = await _read(_child(_shard(id), 'data-$id.json'));
    if (bytes == null) {
      throw const SyncException('已发布的同步快照暂时不可读取', retryable: true);
    }
    if (sha256.convert(bytes).toString() != digest) {
      throw const SyncDataException('同步快照校验不通过');
    }
    try {
      final Object? dataset = await decodeDatasetJson(utf8.decode(bytes));
      if (dataset is Map<String, Object?>) return dataset;
    } on FormatException {
      throw const SyncDataException('同步快照不是有效的 JSON');
    }
    throw const SyncDataException('同步快照不是有效的数据对象');
  }

  Future<String> nextId() async {
    const String shards = '0123456789abcdef';
    final String uuid = const Uuid().v4();
    final int first = shards.indexOf(uuid[0]);
    for (int offset = 0; offset < shards.length; offset++) {
      final String id =
          shards[(first + offset) % shards.length] + uuid.substring(1);
      final entries = await _listDirectory(_shard(id));
      if (entries.length < _publicationLimit) return id;
    }
    throw const SyncDataException('同步快照目录已达写入上限，本机数据已保留');
  }

  Future<String> publish(String id, String json) async {
    final Uri shard = _shard(id);
    final entries = await _listDirectory(shard, create: true);
    final List<int> bytes = utf8.encode(json);
    final String digest = sha256.convert(bytes).toString();
    final String marker = 'done-$id-$digest.v1';
    final Uri markerUri = _child(shard, marker);
    if (entries.length >= _publicationLimit && await _read(markerUri) == null) {
      throw const SyncDataException('同步快照分区已达写入上限，本机数据已保留');
    }
    await _writeOwned(_child(shard, 'data-$id.json'), bytes);
    await _writeOwned(markerUri, utf8.encode(marker));
    final visible = await _listDirectory(shard);
    if (!visible.any(
      (entry) => entry.uri == markerUri && !entry.isCollection,
    )) {
      throw const SyncException('同步快照写入后在目录中不可见', retryable: true);
    }
    return digest;
  }
}
