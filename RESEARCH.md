# Saved macOS `.sb` Baselines: Research, Coverage, and Scanner Design

Research and catalog review date: 2026-10-19
App and corpus: Sandbox Lens
Scope: readable macOS Sandbox Profile Language files, primarily in `/usr/share/sandbox` and `/System/Library/Sandbox/Profiles`

## Executive findings

There is no Apple-hosted, version-indexed repository of every raw `.sb` file from every macOS build. Apple publishes operating-system installers and a release history, but the readable sandbox profiles have to be extracted from an installed system, installer payload, or independently preserved snapshot. Apple also limits installer availability by Mac compatibility and current catalog state: its own instructions say `softwareupdate --list-full-installers` shows the versions currently available for that Mac, and an unavailable version returns “update not found.”[^1] Therefore, “every release” cannot be honestly claimed from public web archives alone.

This project preserves the public macOS snapshots found in the two repositories identified during this research, plus local captures from the research Mac. Their original version/build identifiers remain source declarations, qualified by the companion provenance. The resulting catalog has:

- 23 snapshots;
- 5,953 profile records, including 24 symlink records;
- 18 historical snapshots from `knightsc/sandbox_profiles` (macOS 10.9.5 through 10.15.2, including five beta snapshots);
- one snapshot from `corecryptics/MacOSReports`, retaining the identifier macOS 12.6 (21G115) despite conflicting same-revision version reports;
- four local captures labeled macOS 26.6.2 (25G83), macOS 26.7 (25G229), macOS 27.0 (26A428), and macOS 27.2 (26B5112a);
- pinned community source revisions, per-file SHA-256 fingerprints, and explicit attribution and coverage qualifications.

The most important conclusion is interpretive: a different profile is not automatically “sketchy.” Apple changes the sandbox language and system policies between releases. Mozilla’s own macOS sandbox engineering notes explicitly recommend preserving `/System/Library/Sandbox/Profiles` before an upgrade and diffing it afterward because new macOS releases introduce operations, filters, and policy examples.[^2] Exact product version and build must be matched before treating a byte difference as anomalous.

## 1. What the files represent

Apple describes App Sandbox as kernel-enforced access control intended to contain damage by restricting access to files, network connections, and other resources.[^3] The `.sb` files in this project are human-readable policies or support fragments written in the Scheme-like Sandbox Profile Language (SBPL). Academic work on SandBlaster likewise describes SBPL as the original human-readable form from which Apple sandbox policy can be compiled.[^4]

This study deliberately excludes:

- iOS profile collections, because many iOS built-in profiles are compiled into a different binary representation and are not a comparable macOS release baseline;
- arbitrary third-party `.sb` files whose origin and target OS build cannot be established;
- `.entitlements` files, configuration profiles, and application container metadata, which are different artifact types;
- conclusions about whether a policy was actually loaded or whether a permitted operation occurred.

A static policy provides evidence of configuration or capability. It does not provide runtime evidence. For example, a network `allow` form says that a policy may permit a class of network operations if loaded; it does not prove a connection happened. Likewise, `(with no-sandbox)` deserves explanation and review, but Apple uses such constructs selectively, and the string alone is not proof of malicious child execution.

## 2. Evidence hierarchy

The baseline system uses four source classes, ranked from strongest to weakest:

1. **Local system capture with recorded acquisition evidence.** Product version, build, and architecture can be read from the running system; files are copied read-only from known system locations and hashed. These observations support a comparison with the captured host but do not independently attest Apple authenticity or an exact build's complete policy set.
2. **Apple installer extraction.** A full installer obtained from Apple can provide a build-specific reference without installing it. Apple documents App Store, browser, and Terminal acquisition paths.[^1] Installer extraction still needs careful accounting for payload layout, sealed-system contents, architecture, and post-install updates.
3. **Pinned public snapshot.** A public repository can preserve original paths at an exact Git revision, while OS-build attribution still requires independent evidence. The Knight repository describes itself as a collection from macOS 10.9 through 10.15 with directories matching default install locations.[^5] MacOSReports provides a `Sandbox` collection and conflicting system-report artifacts; its exact profile build remains unresolved.[^6]
4. **Unversioned or incidental copy.** Search results frequently contain one-off `.sb` files or copied system folders. Without a build identifier and provenance, these are useful examples but unsuitable as trusted normality baselines.

The embedded catalog contains public snapshots and local captures. It preserves the original source fields, version/build/channel declarations, installed paths, byte lengths, hashes, and derived markers. `BaselineProvenance.json` qualifies those declarations with attribution status, architecture and acquisition time when known, recorded roots, evidence digests, and limitations. The app checks the companion's catalog SHA-256 and snapshot identifiers before using it, displays its warnings, and includes the selected qualification in specimen exports. Raw Apple policy text and private acquisition evidence remain outside the app bundle and Git.

### Attribution qualifications

- Eighteen community snapshots have pinned source revisions, with OS-build attribution and authenticity still **declared-unverified**.
- The Monterey snapshot is **conflicting**. At the pinned MacOSReports revision, `diagnose-fu/sw_vers.txt` declares 12.6 / 21G115 while `SystemReports/SPSoftwareDataType.spx` declares 12.5 / 21G72. Neither independently identifies the profile build. Both source URLs and evidence digests remain in the companion; the original catalog identifier is preserved. This snapshot has no `/usr/share/sandbox` records.
- The three inherited local snapshots have no source URL/revision, architecture, acquisition date, or independent immutable host evidence. Their stable channels came from the capture script's default and remain unverified.
- The 27.2 / 26B5112a capture records locally observed arm64 architecture and acquisition start `2026-10-19T07:27:20.757415+00:00`. Independent inventories before and after copying agreed on 611 `.sb` paths, 2,833,547 dereferenced bytes, and six symlink declarations, and the saved copy matched. This is point-in-time consistency evidence, not atomic acquisition or independent Apple attestation. The local clock is not an independently attested timestamp. Attribution remains **declared-unverified**, and release channel remains **unknown**.
- All snapshots have **recorded-paths-only** coverage. Recorded roots do not prove complete acquisition. Architecture and acquisition dates for the original 22 snapshots remain unknown; catalog generation time is not acquisition time. Saved-byte consistency does not establish authenticity, effective policy, or runtime authorization.

## 3. Saved coverage

| Declared macOS snapshot | Declared build | Declared channel | Profiles | Source |
|---|---:|---|---:|---|
| 10.9.5 | 13F34 | Stable | 102 | knightsc |
| 10.10.5 | 14F27 | Stable | 122 | knightsc |
| 10.11.6 | 15G31 | Stable | 139 | knightsc |
| 10.12.6 | 16G29 | Stable | 157 | knightsc |
| 10.13.6 | 17G65 | Stable | 179 | knightsc |
| 10.14 beta 7 | 18A365a | Beta | 190 | knightsc |
| 10.14 beta 8 | 18A371a | Beta | 190 | knightsc |
| 10.14 beta 9 | 18A377a | Beta | 190 | knightsc |
| 10.14 beta 10 | 18A384a | Beta | 190 | knightsc |
| 10.14 | 18A391 | Stable | 190 | knightsc |
| 10.14.1 | 18B75 | Stable | 190 | knightsc |
| 10.14.2 | 18C54 | Stable | 191 | knightsc |
| 10.14.4 | 18E226 | Stable | 193 | knightsc |
| 10.14.5 | 18F132 | Stable | 193 | knightsc |
| 10.15 beta 1 | 19A471t | Beta | 217 | knightsc |
| 10.15 | 19A583 | Stable | 223 | knightsc |
| 10.15.1 | 19B88 | Stable | 223 | knightsc |
| 10.15.2 | 19C57 | Stable | 223 | knightsc |
| 12.6 | 21G115 | Stable | 290 | MacOSReports; conflicting attribution |
| 26.6.2 | 25G83 | Stable (unverified) | 570 | Inherited local capture |
| 26.7 | 25G229 | Stable (unverified) | 570 | Inherited local capture |
| 27.0 | 26A428 | Stable (unverified) | 610 | Inherited local capture |
| 27.2 | 26B5112a | Unknown | 611 | Local arm64 capture |

The table preserves source declarations and the qualifications above; it does not independently verify release channels or build attribution. It is a snapshot inventory, not a release-completeness claim. The Apple security-release index demonstrates why the target space is large: it separately enumerates macOS point releases and security updates over time.[^7]

### Confirmed gaps

- 10.9.0–10.9.4 and point builds not listed above;
- 10.10.0–10.10.4;
- 10.11.0–10.11.5;
- 10.12.0–10.12.5;
- 10.13.0–10.13.5;
- 10.14.3 and 10.14.6;
- Catalina after 10.15.2;
- Big Sur 11.x;
- independently attributed Monterey builds, including resolution of the 12.6 / 21G115 versus 12.5 / 21G72 conflict;
- Ventura 13.x;
- Sonoma 14.x;
- Sequoia 15.x;
- Tahoe builds other than the declared 26.6.2 and 26.7 captures;
- macOS 27 builds other than the declared 27.0 and locally observed 27.2 captures.

On the research Mac, `softwareupdate --list-full-installers` offered eleven installers on 2026-09-13: Tahoe 26.5.1 through 26.6.2, Sequoia 15.7.7 through 15.7.9, and Sonoma 14.8.7 through 14.8.9. Together, just one latest build from each supported major line is roughly 46 GB before extraction. They were not silently downloaded because that would consume substantial storage and still would not fill older gaps. Apple’s public download page lists major-version acquisition routes back to Lion, but availability remains compatibility- and catalog-dependent rather than a raw-profile archive.[^1]

## 4. Why nearby releases are not a definitive baseline

The same filename can legitimately change between two ordinary Apple builds. A policy can gain a service exception, remove a temporary path, rename an operation, import a different fragment, or incorporate a security tightening. Even the total installed file set changes over time. Mozilla notes both new rule types and changes in Apple’s own profile examples across macOS releases.[^2]

Accordingly, Sandbox Lens applies these rules:

- An **exact match** requires the same SHA-256 value as the selected record.
- **Different** means the counterpart exists but bytes differ.
- **Missing** means the chosen baseline expects a profile that the scan did not find.
- **Additional** means the scan found a profile absent from the selected baseline.
- **Unverified** means no baseline was selected or no unambiguous counterpart exists.

Only the first is a byte-identity result. It does not resolve declared-unverified or conflicting attribution, even when version/build labels match the host. None of the other statuses independently means malicious. If the product version or build does not exactly match, the UI prominently warns that ordinary OS drift is a leading explanation.

## 5. Comparison method

For standard system scans, files are keyed by full installed path. This avoids accidentally pairing two different profiles that share a filename. For a user-selected export folder, the app can use a filename only if that filename is unique in both the scan and the baseline; otherwise it refuses to invent a counterpart.

Every file is read as UTF-8 and hashed with SHA-256. The analyzer then extracts only a deliberately narrow summary:

- count of `allow` and `deny` forms;
- imported profile names;
- `deny default` or `allow default`;
- unfiltered file-read, file-write, process-exec, or network forms;
- the `no-sandbox` modifier.

These are triage markers, not a full SBPL semantic evaluator. SBPL includes variables, parameters, imports, compound filters, regular expressions, operation variants, and OS-specific compiler behavior. A profile’s effective meaning can depend on its imports and runtime parameters. The app therefore reports when bytes differ but its broad markers do not; it never claims semantic equivalence from this summary.

## 6. Anomaly model

The safest anomaly ranking is evidence-based:

1. **High-confidence integrity anomaly:** an exact-build, exact-path Apple profile differs, and independent evidence confirms the comparison source and local path are both the intended protected system artifacts.
2. **Review-worthy mismatch:** exact-build comparison differs, but installer provenance, sealed-volume state, architecture, or update history has not yet been reconciled.
3. **Expected version drift:** a nearby but non-identical build was selected.
4. **Third-party or imported profile:** a file sits outside the standard Apple locations or has package provenance from installed software.
5. **Capability marker only:** broad syntax exists but there is no evidence of loading or activity.

Escalation should seek corroboration: OS build, architecture, APFS sealed-system status, package receipts, authenticated-root state, signatures for the process that loads the profile, creation/modification metadata, unified logs, and installer hashes. Static policy text alone cannot answer who used the Mac or what a process did.

## 7. App safety and usability design

The app uses a familiar macOS three-column layout:

- the sidebar organizes overview, full inventory, findings, baselines, and education;
- the center column lists releases or files;
- the detail column explains a selected result in plain language and exposes technical evidence when wanted.

The default workflow is one button: **Scan This Mac**. Results use distinct labels instead of a single red “danger” state. “Different,” “missing,” and “additional” are separate because their explanations and next steps differ. Every non-match carries the capability-versus-activity warning. Technical users can inspect hashes, paths, source revisions, rule counts, and imported fragments without making those details the first thing a layperson must understand.

The scanner is read-only. It does not call `sandbox-exec`, compile or load SBPL, bypass filesystem protections, change permissions, remove files, or upload results. User-selected folders use the normal macOS file picker. Apple documents that user-selected file access is a standard sandbox permission pattern for macOS apps.[^3]

## 8. Reproducibility and updating

Three scripts make the corpus reproducible:

- `scripts/acquire_public_baselines.sh OUTPUT_DIRECTORY` clones the known public sources and exports the selected revisions with provenance declarations.
- `scripts/capture_local_baseline.sh OUTPUT_DIRECTORY` captures standard locations on the currently running Mac and records host-reported version/build metadata. Its stable-channel default must be independently reviewed rather than accepted as evidence.
- `scripts/build_baseline_manifest.py --raw-root INPUT_DIRECTORY --output OUTPUT_JSON` validates source metadata, hashes files, derives summaries, and emits the catalog. It does not produce the schema-2 companion or independently verify source attribution.

The bundled catalog and companion were copied unchanged from local SandboxBaselines commit `63ffb6606639f96b20dce8e5189a95aa87f99944`. That repository remains unpublished. Its schema-2 generated-catalog origin pins the SandboxLens generator at revision `95b518082972306a1bc6d3c25e42ca206582aea3` and retains digests of independently saved path/hash manifests. The original 22 snapshot objects and annotations are preserved; 27.2 adds one snapshot without silently upgrading any earlier declaration.

The exact bundled bytes can be checked with:

```sh
shasum -a 256 Sources/SandboxLens/Resources/Baselines.json \
  Sources/SandboxLens/Resources/BaselineProvenance.json
```

Expected SHA-256 values:

| Resource | SHA-256 |
|---|---|
| `Baselines.json` | `f8bc71369b4f0e873c3ec612660396e752e3795a34094780340de637938fd79c` |
| `BaselineProvenance.json` | `940479822e0e3000c71142c26aba0083b81da09cba09058733b64489c622f2b6` |

Update the pair together and preserve the companion's warnings. Regenerating only the catalog changes its digest and is rejected by the loader until the provenance is reviewed and updated consistently. Neither resource contains raw profile text, local evidence locations, or machine diagnostics.

For future releases, the preferred workflow is:

1. Capture the running system before and after an update, or obtain a full installer directly from Apple.
2. Record observed product version, build, architecture, source URL/revision when available, acquisition time, independent evidence, and limitations. Leave unavailable fields unknown.
3. Preserve original paths and symlink information.
4. Generate hashes and compare against at least one independent source when available.
5. Record beta or release-candidate channels only when supported by evidence; otherwise retain unknown.
6. Add the snapshot and matching companion only after validating counts, digests, attribution, and retained warnings.
7. Keep an explicit gap list; never convert absence of a source into a guessed “normal” baseline.

## 9. Interpretation

The app provides exact hashes and paths from 23 saved snapshots, with explicit source declarations and attribution limits. macOS sandbox profiles are build-specific, public coverage is sparse after Catalina, and Apple’s installer catalog is not a complete historical raw-file repository. A catalog digest verifies the saved bytes being used, not the truth of every declaration.

For a layperson, the correct first conclusion from a mismatch is: **“This file differs from the selected reference; check whether the reference exactly matches this Mac.”** A conclusion of tampering requires exact-build provenance and independent corroboration. This distinction is the difference between a useful integrity scanner and an alarm generator.

## Sources

[^1]: Apple Support, [How to download and install macOS](https://support.apple.com/en-us/102662). Documents App Store, browser, Recovery, and `softwareupdate` acquisition; notes compatibility and current-catalog limits.
[^2]: Mozilla Wiki, [Security/Sandbox/macOS Release](https://wiki.mozilla.org/Security/Sandbox/macOS_Release). Describes new sandbox features across macOS releases and recommends directory-level profile comparisons.
[^3]: Apple Developer Documentation, [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox). Describes kernel enforcement, restricted resources, entitlements, and user-selected file access.
[^4]: Deaconescu et al., [SandBlaster: Reversing the Apple Sandbox](https://arxiv.org/abs/1608.04303). Documents human-readable SBPL and compiled sandbox profiles.
[^5]: knightsc, [sandbox_profiles](https://github.com/knightsc/sandbox_profiles). Public version-history corpus whose paths mirror installed locations.
[^6]: corecryptics, [MacOSReports](https://github.com/corecryptics/MacOSReports). Public system-artifact repository containing the Monterey sandbox snapshot with conflicting same-revision version reports.
[^7]: Apple Support, [Apple security releases](https://support.apple.com/en-us/100100). Release and security-update chronology used to bound the target universe.
