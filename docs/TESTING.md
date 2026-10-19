# Testing and verification

Sandbox Lens uses behavior-focused Swift tests, generator tests, repository-integrity checks, real bundle verification, and rendered app inspection.

## Local test commands

Run the Swift suite:

```sh
swift test
```

Run the baseline-generator tests:

```sh
PYTHONPATH=scripts python3 -m unittest discover -s Tests/Scripts -v
```

Check repository boundaries and the bundled manifest:

```sh
python3 scripts/check_repository.py
```

Build, sign, inspect, and open the development app:

```sh
./script/build_and_run.sh --verify
```

Exercise the complete release path:

```sh
./scripts/package_release.sh
```

## Current coverage

The Swift suite contains 52 tests covering:

- bundled catalog and companion decoding, expected corpus totals, digest and identifier consistency, and retained attribution qualifications;
- match, different, missing, additional, and symlink classifications;
- search and category filtering;
- export eligibility for visible selected sources across navigation, filtering, and baseline-only rows;
- recursive read-only scanning;
- scan progress across multiple roots and verified source-text viewing after selection;
- a failed rescan clearing the previous scan verdict;
- rejection of broad, empty, oversized, unreadable, disappeared, and escaping-symlink inputs;
- UTF-8 validation and broad marker extraction;
- comment handling, quoted semicolons, Unicode, whitespace, and malformed-but-readable text;
- exact macOS version formatting, including zero patch versions;
- specimen export byte integrity, checksums, separate provenance, unavailable sources, changed links, scan-root destination rejection, and output failures;
- cleanup after a real exclusive-write collision following a successful payload write, a destination created between staging and publication, and permission-denied cleanup retaining the primary publication failure.

The cleanup-permission case requires an unprivileged macOS user and is explicitly skipped under root. These filesystem cases do not establish disk-full or partial-file-write behavior.

Two Python tests independently cover comment stripping in the baseline generator. The repository check validates ignored corpus boundaries, detects likely credentials and user-specific absolute paths, validates release uniqueness and profile totals, and fails without exposing matched values.

## Release acceptance

A release candidate is acceptable only when all of the following pass:

1. Swift and Python tests.
2. Repository-integrity and shell-syntax checks.
3. Universal arm64/x86_64 release build.
4. Strict code-signature verification of the staged and re-extracted app.
5. Bundle version, build, and minimum-macOS checks.
6. SHA-256 checksum generation.
7. A real app launch and rendered inspection of the overview, profile details, baseline library, and interpretation guide.
8. A live system scan on a matching reference build when such a build is available.

Historical UI evidence for the original catalog was captured from the real app on macOS 27.0 (26A428). The scan read 610 profiles and reported 610 matches, zero different, zero missing, and zero additional. This establishes that host/catalog byte comparison, without independently resolving the inherited capture's attribution.

Native baseline assertions on macOS 27.2 (26B5112a) verified automatic selection of the saved 27.2 reference, a fresh scan with 611 matches and zero different, missing, or additional profiles, and a library of 23 references. The matching overview retained its attribution warning. Baseline details retained the unknown channel, declared-unverified attribution, recorded-paths-only coverage, arm64 observation, acquisition time, and collection limitations. Selecting Monterey retained conflicting attribution, both 21G115 and 21G72 evidence records, and its unresolved-build warning. These assertions establish this host/catalog comparison and visible qualifications, without independently attesting the reference's authenticity or runtime policy.

The separate local XCUITest harness also exercises profile navigation and a populated source viewer. A prior complete run passed at revision `b568f87fa6b368710b92408652e53a93957fff0c` on the same host with the older 27.0 reference. Candidate acceptance must rerun the complete flow against the updated app; baseline assertions alone do not establish successful profile selection or source viewing.

## Deliberate gaps

The native UI harness is a separate local acceptance tool, not a checked-in test target or a hosted CI check. There is no Developer ID signing, notarization, clean-room Gatekeeper test, or independent second-machine scan in the initial release. These gaps must remain visible in release notes rather than being represented as verified behavior. Matching reference labels and hashes do not independently establish build attribution, Apple authenticity, loaded policy, or runtime authorization.
