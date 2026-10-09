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

The Swift suite contains 32 tests covering:

- bundled catalog decoding and expected corpus totals;
- match, different, missing, additional, and symlink classifications;
- search and category filtering;
- export eligibility for visible selected sources across navigation, filtering, and baseline-only rows;
- recursive read-only scanning;
- rejection of broad, empty, oversized, unreadable, disappeared, and escaping-symlink inputs;
- UTF-8 validation and broad marker extraction;
- comment handling, quoted semicolons, Unicode, whitespace, and malformed-but-readable text;
- exact macOS version formatting, including zero patch versions;
- specimen export byte integrity, checksums, separate provenance, unavailable sources, changed links, and output failures.

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

The current UI evidence was captured from the real app on macOS 27.0 (26A428). Its exact-build scan read 610 profiles and reported 610 matches, zero different, zero missing, and zero additional. That validates this host and catalog pairing; it is not a claim about other Macs.

## Deliberate gaps

There are no automated accessibility/UI navigation tests yet. There is also no Developer ID signing, notarization, clean-room Gatekeeper test, or independent second-machine scan in the initial release. These gaps must remain visible in release notes rather than being represented as verified behavior.
