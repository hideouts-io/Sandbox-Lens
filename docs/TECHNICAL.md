# Technical design

Sandbox Lens is a native SwiftUI executable built with Swift Package Manager. It has no third-party runtime dependencies and does not use a privileged helper, system extension, network service, or database.

## Data flow

```text
Selected locations
       |
       v
ProfileScanner -- readable UTF-8 .sb files, metadata, SHA-256
       |                                  |
       |                                  v
       |                         ProfileTextAnalyzer
       |                         narrow static markers
       v
ComparisonEngine <---------------- BaselineRepository
       |                            bundled Baselines.json
       v
AppModel -- filtering and selection -- SwiftUI views
```

The scanner recursively enumerates the selected roots, reads each profile once, computes its SHA-256 digest, and records a narrow static analysis. Files over 16 MiB, invalid UTF-8, inaccessible directories, and unreadable files produce explicit errors.

## Comparison identity

Standard system scans compare the full installed path. This avoids pairing unrelated profiles that happen to share a filename. A copied-folder scan may use a filename only when it is unique in both the scan and the selected baseline; ambiguous candidates remain unmatched.

The comparison classes are intentionally mechanical:

- `match`: counterpart and SHA-256 are equal;
- `different`: counterpart exists and SHA-256 differs;
- `missing`: baseline path has no scanned counterpart;
- `additional`: scanned path has no baseline counterpart;
- `unverified`: a trustworthy one-to-one comparison was not available.

Symbolic-link metadata is retained and can produce a difference even when target bytes match. This prevents a changed filesystem relationship from being hidden by content equality.

## Static analysis boundary

`ProfileTextAnalyzer` removes `;` line comments while preserving semicolons and escapes inside quoted strings. It then extracts counts, imports, defaults, and a few unfiltered forms with deterministic expressions. The Python manifest generator applies the same comment rule.

This is deliberately not a complete grammar. Sandbox Profile Language includes imports, parameters, variables, compound filters, regexes, operation variants, and compiler behavior that varies by OS. The UI labels these values as broad markers rather than effective permissions.

## Baseline format

`Sources/SandboxLens/Resources/Baselines.json` is generated from ignored raw snapshots. Each release stores:

- exact product and build versions;
- channel and human-readable name;
- source name, URL, revision, confidence, and notes;
- installed relative path, filename, size, symlink metadata, and SHA-256;
- narrow derived analysis fields.

The bundle does not contain the raw Apple profile text. `scripts/build_baseline_manifest.py` requires provenance for every input snapshot and fails on missing metadata or invalid UTF-8.

## Security properties

The app is read-only by design. It does not:

- compile, load, or execute a profile;
- invoke `sandbox-exec`;
- request root privileges or alter filesystem permissions;
- modify, quarantine, delete, or upload scanned content;
- infer runtime behavior from static text.

The initial package is intentionally not App Sandbox enabled because its core function is reading system profile locations that are outside a normal app container. User-selected folders still use the standard system file picker. The absence of App Sandbox is a packaging property, not elevated privilege.

## Build and package layout

`Config/AppMetadata.sh` is the single source for bundle identifier, version, build, minimum macOS version, and display name. `scripts/stage_app_bundle.sh` creates the macOS bundle under `dist`, copies the generated SwiftPM resource bundle, writes `Info.plist`, applies an ad-hoc Hardened Runtime signature, and performs strict verification.

`scripts/package_release.sh` additionally builds arm64 and x86_64 slices, creates the ZIP and checksum manifest, extracts the ZIP, and re-verifies the distributed copy. See [SIGNING.md](SIGNING.md) for the trust boundary.
