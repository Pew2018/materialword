# Phase 6.4 — independent cloud backups

## Source baseline and scope

Implementation began from remote `main` at `42d8b21109c273d9bf9c21b7146ea376a5cd9077`. The working tree was clean. The older `9d4c6d4` SHA in the task is a historical audit reference.

This feature adds a separate S3 and WebDAV backup path. `SyncCoordinator` still owns bidirectional sync and its conditional write capability gate. Cloud backup does not call `SyncCoordinator.sync`, use `materialword-data.json`, update sync capability results or update sync timestamps.

## Storage and credentials

`CloudBackupRepository` stores S3 and WebDAV coordinates separately in `app_meta` under `cloud_backup_s3_config` and `cloud_backup_webdav_config`. The preferred target and provider-specific last success receipts are also stored there. No schema migration is needed.

Credential values stay in `SecureCredentialStore`. They use `backup.*` key prefixes and a random epoch suffix. A save first writes both new keychain items, then commits the new config. Failure leaves the old config active. Old epoch items are cleaned up after the switch when possible. If cleanup fails, old secrets are orphaned in secure storage but are never selected by the active config. Deleting a backup config does not delete sync credentials or cloud objects.

The target fingerprint is SHA-256 of provider, normalized target coordinates, addressing mode and credential epoch. A success receipt is displayed only when its fingerprint matches the current target. The receipt timestamp means local completion of upload, readback, validation and receipt persistence; it is distinct from the file name generation time and remote LastModified.

## S3 protocol

`S3BackupProvider` shares `S3Target` URI construction and `AwsV4Signer` with the existing sync provider. It uses a dedicated provider and never calls the sync `upload` method. Each operation generates `materialword-backup-YYYYMMDDTHHMMSSmmmZ-UUIDv4.json` inside the configured prefix. Before PUT, GET must confirm that the name is absent. PUT signs `If-None-Match: *`. If the endpoint rejects the condition with 400 or 501, a second absence check precedes an ordinary PUT. A server that ignores conditions can therefore be used for independent backups. Such a server cannot provide strict atomic non-overwrite guarantees; random names reduce the collision risk, but do not make it zero. This allowance never changes the bidirectional sync capability result.

Successful PUT is followed by GET, byte SHA-256 comparison and full backup JSON validation. A lost PUT response triggers GET of the same object and payload; the operation never re-exports data into that name. Unknown outcomes do not create a success receipt. History uses signed ListObjectsV2 requests with prefix, `max-keys` and continuation token. The signer canonicalizes each query name and value without discarding duplicates or treating `+` as a space.

## WebDAV protocol

`WebDavBackupProvider` uses `WebDavPaths` for HTTPS directory and file URI construction. It confirms or creates the configured directory using PROPFIND and MKCOL, then PUTs a new name and GETs it for verification. Strong ETags and conditional update support are not required. It sends Basic Auth only to the configured HTTPS origin and follows at most three redirects that stay within its configured base path and origin. A Depth 1 PROPFIND supplies history. Returned hrefs must resolve inside the configured directory and match the exact generated backup name; arbitrary external hrefs are never used as authenticated GET targets. The existing directory picker can be opened using a draft provider with the independent backup credentials.

## Download and restore

History shows only generated backup names in the selected target. Downloads are capped at 100 MB even without Content-Length, decoded as UTF-8 and validated with `BackupService.decodeDatasetAsync`. When the selected object matches a local success receipt, its SHA-256 is checked again. Downloads do not modify the database. Users can save the verified JSON through `BackupFiles`, or explicitly choose merge or snapshot restore through `BackupManager`. Snapshot restore creates the existing protective backup and pauses sync. A shared `DataOperationGate` excludes sync and both restore modes on the same database.

## UI and lifecycle

One white icon is in the shared `AppShell` app bar, so all five main pages use the same entry. The dialog reads target-specific receipts and observes the application-level coordinator. `CloudBackupCoordinator` takes its operation lock before the first await, captures config and secrets once, and survives dialog dismissal. S3 and WebDAV forms are separate from the sync form. Network clients injected by tests remain caller-owned; providers close only clients they constructed.

## Diagnostics, tests and remaining validation

Cloud backup stage transitions are logged under `cloud_backup` without credentials, authorization headers, object content or signed requests. The existing diagnostics enable switch and capacity limits apply.

The targeted tests cover config isolation and keychain write failure, a condition-ignoring S3 endpoint, WebDAV without ETag, unique names, signed S3 pagination, no write on unknown object state, malicious WebDAV listing hrefs, readback mismatch, lost PUT response, SigV4 query canonicalization, and the shared app-bar action. Existing S3 sync, WebDAV snapshot sync and sync-settings UI regressions were run. Test details are in the final delivery report.

Real China Science and Technology Cloud S3 and Nutstore WebDAV have not been tested because their credentials were not available. Their behavior is represented only by protocol simulations. Some services may limit the number of files in one WebDAV directory; the client does not claim that a truncated server response is a complete archive. No automatic cloud retention or deletion is performed.

The current transfer API has no cancel action or operating-system background transfer. The connection test reports its current result in the settings page but does not persist a capability cache. A downloaded file from another device has no local trusted upload hash, so structural validation cannot establish that the remote file is unchanged since its creation. A WebDAV server that silently truncates a 207 response without an error or marker cannot be detected as truncated by this client.
