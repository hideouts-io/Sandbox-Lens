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
            }
            .listStyle(.inset)
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
                            Label("Source and confidence", systemImage: "checkmark.seal")
                                .font(.headline)
                            LabeledContent("Source", value: release.sourceName)
                            LabeledContent("Channel", value: release.releaseChannel.capitalized)
                            LabeledContent("Confidence", value: release.confidence.capitalized)
                            Text(release.notes)
                                .foregroundStyle(.secondary)
                            if !release.sourceURL.isEmpty,
                               let url = URL(string: release.sourceURL) {
                                Link("Open source record", destination: url)
                            }
                        }
                    }

                    coverageWarning

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reproducibility")
                            .font(.headline)
                        LabeledContent("Build", value: release.buildVersion)
                        LabeledContent("Source revision", value: release.sourceCommit)
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

    private var coverageWarning: some View {
        Panel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coverage is build-specific")
                        .font(.headline)
                    Text("Apple does not provide a central public archive of raw sandbox profiles for every macOS build. A nearby version is useful for research, but only an exact product version and build supports an exact-baseline verdict.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
