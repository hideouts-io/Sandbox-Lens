import SwiftUI

struct ProfileDetailView: View {
    let comparison: ProfileComparison?
    let baseline: BaselineRelease?
    let revealAction: () -> Void

    var body: some View {
        if let comparison {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(comparison)
                    explanation(comparison)
                    if !comparison.changes.isEmpty {
                        changes(comparison.changes)
                    }
                    if let analysis = comparison.analysis {
                        signals(analysis.reviewSignals)
                    }
                    facts(comparison)
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(28)
            }
        } else {
            EmptyStateView(
                symbol: "sidebar.right",
                title: "Select a profile",
                message: "Choose a profile in the list to see its comparison, broad capability markers, and evidence details."
            )
        }
    }

    private func header(_ comparison: ProfileComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusBadge(status: comparison.status)
            Text(comparison.fileName)
                .font(.largeTitle.weight(.bold))
                .textSelection(.enabled)
            Text(comparison.relativePath)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if comparison.scanned != nil {
                Button(action: revealAction) {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
        }
    }

    private func explanation(_ comparison: ProfileComparison) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                Text("What this result means")
                    .font(.headline)
                Text(comparison.status.plainExplanation)
                    .foregroundStyle(.secondary)
                Text(comparison.method.explanation)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if comparison.status != .match {
                    Text("This result describes a file comparison. It does not establish that the rule was loaded, triggered, or used maliciously.")
                        .font(.callout.weight(.medium))
                        .padding(.top, 3)
                }
            }
        }
    }

    private func changes(_ changes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detected changes")
                .font(.headline)
            ForEach(changes, id: \.self) { change in
                Label(change, systemImage: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func signals(_ signals: [ReviewSignal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Broad capability markers")
                .font(.headline)
            if signals.isEmpty {
                Text("No broad static markers summarized by this version of Sandbox Lens were found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(signals) { signal in
                    DisclosureGroup {
                        Text(signal.plainExplanation)
                            .foregroundStyle(.secondary)
                            .padding(.top, 5)
                    } label: {
                        Label(signal.title, systemImage: "scope")
                    }
                }
            }
        }
    }

    private func facts(_ comparison: ProfileComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evidence details")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                if let scanned = comparison.scanned {
                    factRow("Scanned size", VisualStyle.byteCount(scanned.sizeBytes))
                    factRow("Scanned SHA-256", scanned.sha256)
                    factRow("Scanned file type", scanned.isSymbolicLink ? "Symbolic link" : "Regular file")
                    if let target = scanned.symbolicLinkTarget {
                        factRow("Scanned link target", target)
                    }
                }
                if let expected = comparison.baseline {
                    factRow("Baseline size", VisualStyle.byteCount(expected.sizeBytes))
                    factRow("Baseline SHA-256", expected.sha256)
                    factRow("Baseline file type", expected.isSymbolicLink ? "Symbolic link" : "Regular file")
                    if let target = expected.symbolicLinkTarget {
                        factRow("Baseline link target", target)
                    }
                }
                if let baseline {
                    factRow("Baseline release", baseline.displayName)
                    factRow("Baseline source", baseline.sourceName)
                }
            }
            .font(.callout)
            .textSelection(.enabled)
        }
    }

    private func factRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(value.count == 64 ? .caption.monospaced() : .callout)
                .lineLimit(3)
        }
    }
}
