#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path


TEXT_SUFFIXES = frozenset(
    {".json", ".md", ".py", ".sb", ".sh", ".swift", ".toml", ".yaml", ".yml"}
)
FORBIDDEN_PREFIXES = (".build/", "dist/", "ResearchCorpus/raw/")
SENSITIVE_SUFFIXES = frozenset({".cer", ".key", ".mobileprovision", ".p12", ".pem"})
SENSITIVE_FILENAMES = frozenset({"id_dsa", "id_ecdsa", "id_ed25519", "id_rsa"})


def repository_paths(root: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    decoded = result.stdout.decode("utf-8")
    return sorted(root / value for value in decoded.split("\0") if value)


def relative_path(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def validate_repository_boundaries(root: Path, paths: list[Path]) -> None:
    violations = [
        relative_path(root, path)
        for path in paths
        if any(
            relative_path(root, path).startswith(prefix)
            and relative_path(root, path) != "ResearchCorpus/raw/.gitkeep"
            for prefix in FORBIDDEN_PREFIXES
        )
    ]
    if violations:
        raise ValueError(
            "Generated build output or raw profile material is included in the "
            f"repository candidate set: {violations}"
        )

    sensitive_files = [
        relative_path(root, path)
        for path in paths
        if path.suffix.lower() in SENSITIVE_SUFFIXES
        or path.name.lower() in SENSITIVE_FILENAMES
    ]
    if sensitive_files:
        raise ValueError(
            "Certificate, provisioning, or private-key files are included in the "
            f"repository candidate set: {sensitive_files}"
        )


def validate_sensitive_text(root: Path, paths: list[Path]) -> None:
    patterns = (
        (
            "a private-key block",
            re.compile("BEGIN " + r"(?:RSA |EC |OPENSSH )?PRIVATE KEY"),
        ),
        ("a GitHub token", re.compile(r"(?:gh[opusr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})")),
        ("an AWS access key", re.compile(r"AKIA[0-9A-Z]{16}")),
        (
            "an email address",
            re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
        ),
        (
            "a device-like UUID",
            re.compile(
                r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
                r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"
            ),
        ),
        (
            "an absolute macOS user path",
            re.compile("/" + "Users" + r"/[^/\s]+/"),
        ),
        (
            "an absolute Linux user path",
            re.compile("/" + "home" + r"/[^/\s]+/"),
        ),
    )
    violations: list[str] = []
    for path in paths:
        if path.suffix not in TEXT_SUFFIXES or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for label, pattern in patterns:
            if pattern.search(text):
                violations.append(f"{relative_path(root, path)} contains {label}")
    if violations:
        raise ValueError(
            "Potentially sensitive repository content was found without printing "
            f"the matched values: {violations}"
        )


def validate_baseline_manifest(root: Path) -> None:
    manifest_path = root / "Sources/SandboxLens/Resources/Baselines.json"
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise TypeError(f"Baseline manifest root must be an object: {manifest_path}")
    if payload.get("schemaVersion") != 1:
        raise ValueError(f"Unsupported baseline schema in {manifest_path}")
    releases = payload.get("releases")
    if not isinstance(releases, list) or not releases:
        raise ValueError(f"Baseline manifest has no releases: {manifest_path}")

    identifiers: set[str] = set()
    for release in releases:
        if not isinstance(release, dict):
            raise TypeError(f"Baseline release must be an object: {manifest_path}")
        identifier = release.get("id")
        profiles = release.get("profiles")
        profile_count = release.get("profileCount")
        if not isinstance(identifier, str) or not identifier:
            raise ValueError(f"Baseline release has no identifier: {manifest_path}")
        if identifier in identifiers:
            raise ValueError(f"Duplicate baseline identifier: {identifier}")
        identifiers.add(identifier)
        if not isinstance(profiles, list) or profile_count != len(profiles):
            raise ValueError(
                f"Baseline profile count does not match records: {identifier}"
            )


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    paths = repository_paths(root)
    validate_repository_boundaries(root, paths)
    validate_sensitive_text(root, paths)
    validate_baseline_manifest(root)
    print(f"Repository checks passed for {len(paths)} candidate files.")


if __name__ == "__main__":
    main()
