# Security policy

## Supported versions

Security fixes are provided for the latest published release. Pre-release source on the default branch may change without compatibility guarantees.

## Report a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/hideouts-io/Sandbox-Lens/security/advisories/new). Do not open a public issue for a vulnerability that could put users or systems at risk.

Include the affected version, macOS version/build, reproduction steps, impact, and the smallest safe diagnostic sample. Do not send credentials, full home-directory paths, raw private profiles, or unrelated system data.

## Scope

Useful reports include unintended file modification, path traversal, unsafe symlink handling, incorrect trust claims, release-integrity problems, or a way for scanned content to trigger execution. A static `allow` form in an Apple or third-party profile is not itself a Sandbox Lens vulnerability.

Sandbox Lens does not promise to determine whether a system is compromised. Its findings require build-matched provenance and independent corroboration.
