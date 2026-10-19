import SwiftUI

struct BaselineLibraryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Baseline library")
                    .font(.title2.weight(.semibold))
                Text("Saved fingerprints and static summaries from sourced macOS snapshots")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(model.releases.count) saved references")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("baseline.libraryCount")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            Divider()
            List(model.releases, selection: $model.selectedBaselineID) { release in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(release.displayName)
                            .font(.body.weight(.medium))
                        if release.isBeta {
                            Text("BETA")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("\(release.profileCount) profiles · \(release.sourceName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .tag(Optional(release.id))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("baseline.\(release.id)")
                .accessibilityLabel("\(release.displayName), \(release.profileCount) profiles, \(release.sourceName)")
            }
            .listStyle(.inset)
            .accessibilityIdentifier("baseline.library")
        }
    }
}

struct BaselineDetailView: View {
    let release: BaselineRelease?

    var body: some View {
        if let release {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(release.displayName)
                            .font(.largeTitle.weight(.bold))
                        Text("\(release.profileCount) readable .sb profiles")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Source declarations", systemImage: "doc.text.magnifyingglass")
                                .font(.headline)
                            LabeledContent("Source", value: release.sourceName)
                            detailField(
                                title: "Channel",
                                value: release.releaseChannel.capitalized,
                                identifier: "baseline.detail.channel"
                            )
                            detailField(
                                title: "Declared confidence",
                                value: release.confidence,
                                identifier: "baseline.detail.confidence"
                            )
                            Text(release.notes)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("baseline.detail.notes")
                            if !release.sourceURL.isEmpty,
                               let url = URL(string: release.sourceURL) {
                                Link("Open source record", destination: url)
                            }
                        }
                    }

                    if let provenance = release.provenance {
                        provenanceDetails(provenance)
                    }

                    coverageWarning

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reproducibility")
                            .font(.headline)
                        LabeledContent("Build", value: release.buildVersion)
                        LabeledContent("Source revision", value: release.sourceCommit.isEmpty ? "Not recorded" : release.sourceCommit)
                        Text("The embedded app catalog contains paths, sizes, SHA-256 fingerprints, and broad static markers. Raw Apple profile text remains in the local research corpus and is not redistributed in the app bundle.")
                            .foregroundStyle(.secondary)
                    }
                    .textSelection(.enabled)
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(28)
            }
        } else {
            EmptyStateView(
                symbol: "books.vertical",
                title: "Choose a baseline",
                message: "Select a release to inspect its source, coverage, and reproducibility details."
            )
        }
    }

    private func detailField(title: String, value: String, identifier: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .accessibilityIdentifier(identifier)
        }
    }

    private func provenanceDetails(_ provenance: BaselineProvenance) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                BaselineProvenanceNotice(
                    provenance: provenance,
                    identifier: "baseline.detail.provenanceNotice"
                )
                detailField(
                    title: "Attribution",
                    value: provenance.attribution.rawValue,
                    identifier: "baseline.detail.attribution"
                )
                detailField(
                    title: "Coverage",
                    value: provenance.coverage.rawValue,
                    identifier: "baseline.detail.coverage"
                )
                detailField(
                    title: "Observed architecture",
                    value: provenance.architecture ?? "Not recorded",
                    identifier: "baseline.detail.architecture"
                )
                detailField(
                    title: "Observed acquisition time",
                    value: provenance.collectedAt ?? "Not recorded",
                    identifier: "baseline.detail.collectedAt"
                )
                LabeledContent("Recorded roots", value: provenance.roots.joined(separator: "\n"))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provenance limitations")
                        .font(.headline)
                    Text(provenance.limitations.joined(separator: "\n\n"))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("baseline.detail.limitations")
                }

                if !provenance.evidence.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source version reports")
                            .font(.headline)
                        Text(provenance.evidence.map { evidence in
                            "macOS \(evidence.productVersion) (\(evidence.buildVersion))\n\(evidence.url)\nSHA-256: \(evidence.sha256)"
                        }.joined(separator: "\n\n"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("baseline.detail.evidence")
                    }
                }
            }
        }
    }

    private var coverageWarning: some View {
        Panel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Review coverage and attribution")
                        .font(.headline)
                    Text("A matching product version and build selects recorded fingerprints. Independent provenance and collection scope must also be reviewed; matching declarations alone do not establish an authoritative reference.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
