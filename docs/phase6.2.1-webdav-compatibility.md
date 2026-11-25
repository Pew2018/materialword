# Phase 6.2.1 WebDAV compatibility

This change preserves Phase 6.2 conditional-write protection and Phase 6.3 localization.

Implemented:
- Base URL reconstruction does not introduce an empty query or fragment.
- Read-only PROPFIND uses collection, listing and file metadata property profiles, retrying 400/405/415 with text/xml and then a bodyless request.
- HTTP 400 at the base probe is classified as request rejection, without claiming authentication or directory access.
- Folder selection and creation are disabled after listing failure; an error is not rendered as an empty folder.
- Malformed or absent href elements are ignored; file size is selected by matching the requested URI.
- Trace records the actual redirect hop, query presence, request depth/profile/mode and a bounded server XML error string.

Still to verify or extend:
- Dynamic Depth 0/1 capability negotiation and persistent compatibility caching.
- Per-resource ETag selection in multistatus responses.
- Real Nutstore PROPFIND, CRUD, strong ETag and conditional-write semantics.
- Android/macOS cross-device data merge and all three release artifacts.

A local server or CI run does not establish real Nutstore compatibility. Do not enable bidirectional sync unless the existing strong ETag and conditional-write probes pass.
