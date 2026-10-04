# Contributing

Contributions are welcome when they preserve Sandbox Lens’s evidence-first and read-only model.

## Before opening a pull request

1. Open an issue for a material behavior or data-model change.
2. Keep changes focused and avoid unrelated formatting.
3. Add the minimum behavior-focused tests needed for the change.
4. Run the commands in [docs/TESTING.md](docs/TESTING.md).
5. Confirm that no raw Apple profile text, credentials, local paths, build output, or personal data is included.

## Code expectations

- Prefer native Swift and platform-recommended APIs.
- Keep data flow explicit and functions single-purpose.
- Fail with actionable errors rather than silently skipping unreadable or invalid inputs.
- Do not add network access, telemetry, policy execution, privilege escalation, remediation, or destructive behavior without prior design discussion.
- Maintain the distinction between static capability, observed activity, and evidence of compromise.

## Baseline contributions

A baseline proposal must include reproducible provenance:

- exact macOS product version and build;
- release channel and architecture;
- original source URL or documented local-capture method;
- exact source revision or installer identity;
- acquisition date and confidence notes;
- original installed paths and symlink metadata.

Do not commit raw profile text. Generate the derived manifest locally and include only the resulting catalog change plus provenance documentation that is legally redistributable. A nearby version, an unattributed archive, or a filename-only collection is not sufficient for a trusted baseline.

## Pull requests

Explain the user-visible problem, evidence for the change, tests performed, and any remaining validation gap. Screenshots are useful for UI changes, but they must not expose usernames, device identifiers, or unrelated files.
