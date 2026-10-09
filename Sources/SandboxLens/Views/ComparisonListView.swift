import SwiftUI

struct ComparisonListView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.scanResult == nil {
                EmptyStateView(
                    symbol: "doc.text.magnifyingglass",
                    title: "No scan yet",
                    message: "Scan this Mac or choose a folder to compare readable sandbox profiles with a known baseline."
                )
            } else if model.filteredComparisons.isEmpty {
                EmptyStateView(
                    symbol: "checkmark.circle",
                    title: "Nothing in this category",
                    message: "No profiles match the current filter and search."
                )
            } else {
                List(model.filteredComparisons, selection: $model.selectedComparisonID) { comparison in
                    ComparisonRow(comparison: comparison)
                        .tag(Optional(comparison.id))
                        .accessibilityIdentifier("profile.\(comparison.id)")
                }
                .listStyle(.inset)
            }
        }
        .onChange(of: model.selectedDestination) { _ in
            model.selectFirstVisibleComparison()
        }
        .onChange(of: model.searchText) { _ in
            model.selectFirstVisibleComparison()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.selectedDestination.title)
                        .font(.title2.weight(.semibold))
                    Text(listSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            TextField("Search profiles", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
    }

    private var listSubtitle: String {
        if let baseline = model.selectedBaseline {
            return "Compared with \(baseline.displayName)"
        }
        return "Showing scanned files without a baseline verdict"
    }
}

private struct ComparisonRow: View {
    let comparison: ProfileComparison

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: VisualStyle.symbol(for: comparison.status))
                .foregroundStyle(VisualStyle.color(for: comparison.status))
                .font(.body.weight(.semibold))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(comparison.fileName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(comparison.relativePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(comparison.status.shortTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VisualStyle.color(for: comparison.status))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
