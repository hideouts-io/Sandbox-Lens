# Published macOS `.sb` Baselines: Research, Coverage, and Scanner Design

Research date: 2026-10-01
App and corpus: Sandbox Lens
Scope: readable macOS Sandbox Profile Language files, primarily in `/usr/share/sandbox` and `/System/Library/Sandbox/Profiles`

## Executive findings

There is no Apple-hosted, version-indexed repository of every raw `.sb` file from every macOS build. Apple publishes operating-system installers and a release history, but the readable sandbox profiles have to be extracted from an installed system, installer payload, or independently preserved snapshot. Apple also limits installer availability by Mac compatibility and current catalog state: its own instructions say `softwareupdate --list-full-installers` shows the versions currently available for that Mac, and an unavailable version returns “update not found.”[^1] Therefore, “every release” cannot be honestly claimed from public web archives alone.

This project preserves every attributable public macOS snapshot found in the two useful repositories identified during this research, plus exact captures from the research Mac. The resulting local corpus has:

- 22 build-specific release snapshots;
- 5,342 profile records;
- 18 historical snapshots from `knightsc/sandbox_profiles` (macOS 10.9.5 through 10.15.2, including five beta snapshots);
- one macOS 12.6 (21G115) snapshot from `corecryptics/MacOSReports`;
- three local captures: macOS 26.6.2 (25G83), macOS 26.7 (25G229), and macOS 27.0 (26A428);
- exact source revisions and per-file SHA-256 fingerprints.

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

1. **Exact local Apple system capture.** Product version and build are read from the running system; files are copied read-only from known system locations and hashed. This is strongest for comparing that same build and architecture.
2. **Apple installer extraction.** A full installer obtained from Apple can provide a build-specific reference without installing it. Apple documents App Store, browser, and Terminal acquisition paths.[^1] Installer extraction still needs careful accounting for payload layout, sealed-system contents, architecture, and post-install updates.
3. **Attributable public snapshot.** A public repository is usable when it preserves original paths and a release/build can be tied to an exact Git revision. The Knight repository describes itself as a collection from macOS 10.9 through 10.15 with directories matching default install locations.[^5] MacOSReports provides a larger `Sandbox` collection and system-report artifacts used here to identify its build.[^6]
4. **Unversioned or incidental copy.** Search results frequently contain one-off `.sb` files or copied system folders. Without a build identifier and provenance, these are useful examples but unsuitable as trusted normality baselines.

The embedded catalog includes the first three classes only. It records source name, URL, exact source commit, confidence, notes, product version, build, release channel, installed path, byte length, hash, and derived markers. Raw Apple policy text stays in the ignored local research directory instead of being redistributed in the app bundle.

## 3. Saved coverage

| macOS snapshot | Build | Channel | Profiles | Source |
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
| 12.6 | 21G115 | Stable | 290 | MacOSReports |
| 26.6.2 | 25G83 | Stable | 570 | Exact local capture |
| 26.7 | 25G229 | Stable | 570 | Exact local capture |
| 27.0 | 26A428 | Stable | 610 | Exact local capture |

This table is a snapshot inventory, not a release-completeness claim. The Apple security-release index demonstrates why the target space is large: it separately enumerates macOS point releases and security updates over time.[^7]

### Confirmed gaps

- 10.9.0–10.9.4 and point builds not listed above;
- 10.10.0–10.10.4;
- 10.11.0–10.11.5;
- 10.12.0–10.12.5;
- 10.13.0–10.13.5;
- 10.14.3 and 10.14.6;
- Catalina after 10.15.2;
- Big Sur 11.x;
- Monterey builds other than the attributed 12.6 capture;
- Ventura 13.x;
- Sonoma 14.x;
- Sequoia 15.x;
- Tahoe builds other than the exact 26.6.2 and 26.7 captures;
- macOS 27 builds other than the exact 27.0 capture.

On the research Mac, `softwareupdate --list-full-installers` offered eleven installers on 2026-09-13: Tahoe 26.5.1 through 26.6.2, Sequoia 15.7.7 through 15.7.9, and Sonoma 14.8.7 through 14.8.9. Together, just one latest build from each supported major line is roughly 46 GB before extraction. They were not silently downloaded because that would consume substantial storage and still would not fill older gaps. Apple’s public download page lists major-version acquisition routes back to Lion, but availability remains compatibility- and catalog-dependent rather than a raw-profile archive.[^1]

## 4. Why nearby releases are not a definitive baseline

The same filename can legitimately change between two ordinary Apple builds. A policy can gain a service exception, remove a temporary path, rename an operation, import a different fragment, or incorporate a security tightening. Even the total installed file set changes over time. Mozilla notes both new rule types and changes in Apple’s own profile examples across macOS releases.[^2]

Accordingly, Sandbox Lens applies these rules:

- An **exact match** requires the same SHA-256 value as the selected record.
- **Different** means the counterpart exists but bytes differ.
- **Missing** means the chosen baseline expects a profile that the scan did not find.
- **Additional** means the scan found a profile absent from the selected baseline.
- **Unverified** means no baseline was selected or no unambiguous counterpart exists.

Only the first is a byte-identity result. None of the other statuses independently means malicious. If the product version or build does not exactly match, the UI prominently warns that ordinary OS drift is a leading explanation.

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

- `scripts/acquire_public_baselines.sh OUTPUT_DIRECTORY` clones the known public sources and exports every attributable revision with provenance.
- `scripts/capture_local_baseline.sh OUTPUT_DIRECTORY` captures standard locations on the currently running Mac and writes its exact version/build metadata.
- `scripts/build_baseline_manifest.py INPUT_DIRECTORY OUTPUT_JSON` validates provenance, hashes files, derives summaries, and emits the bundled catalog.

For future releases, the preferred workflow is:

1. Capture the running system before and after an update, or obtain a full installer directly from Apple.
2. Record exact product version, build, architecture, source URL, acquisition time, and source hash/revision.
3. Preserve original paths and symlink information.
4. Generate hashes and compare against at least one independent source when available.
5. Mark beta and release-candidate material separately.
6. Add the snapshot only after validating counts and provenance.
7. Keep an explicit gap list; never convert absence of a source into a guessed “normal” baseline.

## 9. Bottom line

The app now provides a strong, honest baseline mechanism: exact hashes and paths from 22 sourced builds, clear source labels, a reproducible acquisition process, and cautious explanations. It also makes the central limitation visible: macOS sandbox profiles are build-specific, public coverage is sparse after Catalina, and Apple’s installer catalog is not a complete historical raw-file repository.

For a layperson, the correct first conclusion from a mismatch is: **“This file differs from the selected reference; check whether the reference exactly matches this Mac.”** A conclusion of tampering requires exact-build provenance and independent corroboration. This distinction is the difference between a useful integrity scanner and an alarm generator.

## Sources

[^1]: Apple Support, [How to download and install macOS](https://support.apple.com/en-us/102662). Documents App Store, browser, Recovery, and `softwareupdate` acquisition; notes compatibility and current-catalog limits.
[^2]: Mozilla Wiki, [Security/Sandbox/macOS Release](https://wiki.mozilla.org/Security/Sandbox/macOS_Release). Describes new sandbox features across macOS releases and recommends directory-level profile comparisons.
[^3]: Apple Developer Documentation, [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox). Describes kernel enforcement, restricted resources, entitlements, and user-selected file access.
[^4]: Deaconescu et al., [SandBlaster: Reversing the Apple Sandbox](https://arxiv.org/abs/1608.04303). Documents human-readable SBPL and compiled sandbox profiles.
[^5]: knightsc, [sandbox_profiles](https://github.com/knightsc/sandbox_profiles). Public version-history corpus whose paths mirror installed locations.
[^6]: corecryptics, [MacOSReports](https://github.com/corecryptics/MacOSReports). Public system-artifact repository containing the attributed Monterey sandbox snapshot.
[^7]: Apple Support, [Apple security releases](https://support.apple.com/en-us/100100). Release and security-update chronology used to bound the target universe.
