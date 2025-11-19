## 0.3.2 (2025-11-19)

### Improved
- Internal request logging now clearly displays the final AMPRE request path for easier debugging.
- Media filter logic now mirrors the stable pattern used in Property replication filters.

### Fixed
- Corrected Media API $filter construction to comply with AMPRE OData requirements.
- Removed incorrect manual URI-encoding that caused 400 The URI is malformed errors.
- Resolved issues where HTTPClient encoding differed from curl behavior, ensuring valid query formation.
- Restored full pagination functionality for media fetching via:
  - `fetch_all_media_for_resource`

## 0.3.1 (2025-11-18)

### Added
- Full media pagination support:
  - `fetch_media_batch`
  - `each_media_batch`
  - `fetch_all_media_for_listing`
- Media batching now matches the Property replication architecture.
- Support for listing-level media syncs with ordered pagination (`Order asc, MediaKey`).

### Improved
- Internal consistency updates across API helper layers.

### Fixed
- Minor documentation improvements around Media calls.

## 0.2.2

#### Enhancements

- Added lookup helpers:
  - `fetch_lookup_batch`
  - `each_lookup_batch`
  - `fetch_all_lookups`
  - `lookup(lookup_name, batch_size:, sleep_seconds:)`
  These support optional filters and configurable sleep intervals for safer long-running syncs.

- Added replication helpers:
  - `fetch_initial_download_batch`
  - `each_initial_download_batch`
  - Improved `perform_initial_download` and `fetch_updates` to support batch-style processing and resumable checkpoints.

- Improved internal filter construction for replication queries to better combine user-provided filters with checkpoint-based ranges.


## 0.1.0

API Client for use with Amplify Syndication API

#### Includes API endpoints for
- property 
- media
