#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True)
class ProfileAnalysis:
    allow_count: int
    deny_count: int
    imports: list[str]
    has_deny_default: bool
    has_allow_default: bool
    has_global_file_read: bool
    has_global_file_write: bool
    has_global_file_read_write: bool
    has_global_process_exec: bool
    has_global_network: bool
    has_no_sandbox_execution: bool


@dataclass(frozen=True)
class BaselineProfile:
    relative_path: str
    file_name: str
    sha256: str
    size_bytes: int
    is_symbolic_link: bool
    symbolic_link_target: str | None
    analysis: ProfileAnalysis


@dataclass(frozen=True)
class Provenance:
    id: str
    display_name: str
    product_version: str
    build_version: str
    release_channel: str
    source_name: str
    source_url: str
    source_commit: str
    confidence: str
    notes: str


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Sandbox Lens baseline metadata from raw SBPL snapshots."
    )
    parser.add_argument("--raw-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def load_provenance(release_directory: Path) -> Provenance:
    provenance_path = release_directory / "provenance.json"
    raw = json.loads(provenance_path.read_text(encoding="utf-8"))
    required_fields = {
        "id",
        "displayName",
        "productVersion",
        "buildVersion",
        "releaseChannel",
        "sourceName",
        "sourceURL",
        "sourceCommit",
        "confidence",
        "notes",
    }
    missing_fields = sorted(required_fields - raw.keys())
    if missing_fields:
        raise ValueError(
            f"Missing provenance fields in {provenance_path}: {missing_fields}"
        )
    return Provenance(
        id=str(raw["id"]),
        display_name=str(raw["displayName"]),
        product_version=str(raw["productVersion"]),
        build_version=str(raw["buildVersion"]),
        release_channel=str(raw["releaseChannel"]),
        source_name=str(raw["sourceName"]),
        source_url=str(raw["sourceURL"]),
        source_commit=str(raw["sourceCommit"]),
        confidence=str(raw["confidence"]),
        notes=str(raw["notes"]),
    )


def analyze_profile(text: str) -> ProfileAnalysis:
    uncommented_text = remove_line_comments(text)
    import_pattern = re.compile(r'\(import\s+"([^"]+)"\)')
    return ProfileAnalysis(
        allow_count=len(re.findall(r"\(allow(?:\s|\()", uncommented_text)),
        deny_count=len(re.findall(r"\(deny(?:\s|\()", uncommented_text)),
        imports=sorted(set(import_pattern.findall(uncommented_text))),
        has_deny_default=bool(re.search(r"\(deny\s+default\b", uncommented_text)),
        has_allow_default=bool(re.search(r"\(allow\s+default\b", uncommented_text)),
        has_global_file_read=bool(
            re.search(r"\(allow\s+file-read\*\s*\)", uncommented_text)
        ),
        has_global_file_write=bool(
            re.search(r"\(allow\s+file-write\*\s*\)", uncommented_text)
        ),
        has_global_file_read_write=bool(
            re.search(
                r"\(allow\s+file-read\*\s+file-write\*\s*\)", uncommented_text
            )
        ),
        has_global_process_exec=bool(
            re.search(r"\(allow\s+process-exec\s*\)", uncommented_text)
        ),
        has_global_network=bool(
            re.search(r"\(allow\s+network\*\s*\)", uncommented_text)
        ),
        has_no_sandbox_execution="(with no-sandbox)" in uncommented_text,
    )


def remove_line_comments(text: str) -> str:
    result: list[str] = []
    is_inside_string = False
    is_escaped = False
    is_inside_comment = False

    for character in text:
        if is_inside_comment:
            if character == "\n" or character == "\r":
                is_inside_comment = False
                result.append(character)
            continue

        if is_inside_string:
            result.append(character)
            if is_escaped:
                is_escaped = False
            elif character == "\\":
                is_escaped = True
            elif character == '"':
                is_inside_string = False
            continue

        if character == ";":
            is_inside_comment = True
        else:
            result.append(character)
            if character == '"':
                is_inside_string = True

    return "".join(result)


def build_profile(release_directory: Path, profile_path: Path) -> BaselineProfile:
    data = profile_path.read_bytes()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ValueError(f"Profile is not valid UTF-8: {profile_path}") from error
    relative_path = profile_path.relative_to(release_directory).as_posix()
    return BaselineProfile(
        relative_path=relative_path,
        file_name=profile_path.name,
        sha256=hashlib.sha256(data).hexdigest(),
        size_bytes=len(data),
        is_symbolic_link=profile_path.is_symlink(),
        symbolic_link_target=(
            profile_path.readlink().as_posix() if profile_path.is_symlink() else None
        ),
        analysis=analyze_profile(text),
    )


def encode_profile(profile: BaselineProfile) -> dict[str, object]:
    encoded = asdict(profile)
    encoded["relativePath"] = encoded.pop("relative_path")
    encoded["fileName"] = encoded.pop("file_name")
    encoded["sizeBytes"] = encoded.pop("size_bytes")
    encoded["isSymbolicLink"] = encoded.pop("is_symbolic_link")
    encoded["symbolicLinkTarget"] = encoded.pop("symbolic_link_target")
    analysis = encoded["analysis"]
    if not isinstance(analysis, dict):
        raise TypeError(f"Unexpected encoded analysis type: {type(analysis)}")
    for snake_name in list(analysis.keys()):
        parts = snake_name.split("_")
        camel_name = parts[0] + "".join(part.title() for part in parts[1:])
        analysis[camel_name] = analysis.pop(snake_name)
    return encoded


def encode_release(release_directory: Path) -> dict[str, object]:
    provenance = load_provenance(release_directory)
    profile_paths = sorted(release_directory.rglob("*.sb"))
    profiles = [build_profile(release_directory, item) for item in profile_paths]
    return {
        "id": provenance.id,
        "displayName": provenance.display_name,
        "productVersion": provenance.product_version,
        "buildVersion": provenance.build_version,
        "releaseChannel": provenance.release_channel,
        "sourceName": provenance.source_name,
        "sourceURL": provenance.source_url,
        "sourceCommit": provenance.source_commit,
        "confidence": provenance.confidence,
        "notes": provenance.notes,
        "profileCount": len(profiles),
        "profiles": [encode_profile(item) for item in profiles],
    }


def main() -> None:
    arguments = parse_arguments()
    raw_root: Path = arguments.raw_root
    output_path: Path = arguments.output
    if not raw_root.is_dir():
        raise FileNotFoundError(f"Raw baseline root does not exist: {raw_root}")

    release_directories = sorted(
        item for item in raw_root.iterdir() if (item / "provenance.json").is_file()
    )
    if not release_directories:
        raise ValueError(f"No releases with provenance.json found under {raw_root}")

    payload = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "releases": [encode_release(item) for item in release_directories],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
