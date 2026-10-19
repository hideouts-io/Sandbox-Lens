# Changelog

All notable user-facing changes are documented here.

## [Unreleased]

### Added

- Runtime research specimen export with verified source bytes, static provenance, and checksums for external testing.
- Read-only source-text viewing that rechecks the selected profile against its scan, plus scan progress.
- Saved macOS 27.2 / 26B5112a reference, bringing the catalog to 23 snapshots and 5,953 profile records.
- Digest-bound provenance qualifications in baseline details and specimen exports, preserving declared-unverified attribution, the Monterey version/build conflict, and unknown acquisition fields and release channels.

### Fixed

- Clear previous scan results and export eligibility when a rescan fails or a folder is rejected.
- Reject specimen destinations inside scanned folders, including symlinked routes, and preserve exclusive output publication.

## [0.1.1] - 2026-10-07

### Changed

- Apply the approved Profile Print logo to the macOS app icon, overview, and welcome view.
- Add matching light and dark README headers, repository banners, and social-preview artwork.
- Refresh the overview screenshot from the branded app.

## [0.1.0] - 2026-10-04

### Added

- Native three-column macOS interface with plain-language overview and technical evidence views.
- Read-only standard-location and copied-folder scanners.
- Exact path, SHA-256, and symlink-aware comparison categories.
- Narrow static marker summaries with explicit capability-versus-activity guidance.
- Build-specific baseline catalog with 22 snapshots and 5,342 derived records.
- Search, result filtering, baseline provenance, and an in-app interpretation guide.
- Universal arm64/x86_64 packaging, checksum generation, CI, and release verification.

[Unreleased]: https://github.com/hideouts-io/Sandbox-Lens/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/hideouts-io/Sandbox-Lens/releases/tag/v0.1.1
[0.1.0]: https://github.com/hideouts-io/Sandbox-Lens/releases/tag/v0.1.0
