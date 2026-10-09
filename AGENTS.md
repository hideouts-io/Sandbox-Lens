# Sandbox Lens

## Validation and evidence

- Read `CONTRIBUTING.md`, `SECURITY.md`, and `docs/TESTING.md`; use the latter as the canonical build, test, packaging, and acceptance guide.
- Preserve Swift behavior tests, baseline-generator tests, repository-boundary checks, shell checks, and the universal release build in PR CI. Keep the read-only, local evidence model and build-matched baseline provenance requirements.
- Never publish raw profile text, private scan data, credentials, personal paths, or machine-generated reports. Use derived manifests and legally redistributable provenance.
- Verify candidate-revision CodeQL analyses for Swift, Python, and GitHub Actions. Tests and static analysis do not establish rendered UI behavior, a matching reference-host scan, notarization, or independent-machine acceptance.
- Keep CodeQL extraction/build jobs read-only. Upload SARIF in a separate job that runs no repository code, and preserve the strict `CodeQL results` gate across every language.

## Publication

- Release tags use `v*` and require `docs/releases/<tag>.md`. Follow the version and release acceptance rules in `docs/TESTING.md` and `scripts/package_release.sh`.
- The `github-release` environment requires the repository owner's approval before packaging/publication runs. Agents must not approve that gate; creating a tag or executing CI does not authorize an actual product release.
- Keep the documented Developer ID, notarization, Gatekeeper, UI, and second-machine gaps visible in release notes until independently verified.
