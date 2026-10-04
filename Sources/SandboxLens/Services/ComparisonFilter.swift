import Foundation

enum ComparisonFilter {
    static func apply(
        comparisons: [ProfileComparison],
        destination: SidebarDestination,
        query: String
    ) -> [ProfileComparison] {
        let destinationFiltered: [ProfileComparison]
        switch destination {
        case .changed:
            destinationFiltered = comparisons.filter { $0.status == .changed }
        case .missing:
            destinationFiltered = comparisons.filter { $0.status == .missing }
        case .unexpected:
            destinationFiltered = comparisons.filter { $0.status == .unexpected }
        default:
            destinationFiltered = comparisons
        }

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return destinationFiltered
        }
        return destinationFiltered.filter {
            $0.fileName.localizedCaseInsensitiveContains(normalizedQuery) ||
                $0.relativePath.localizedCaseInsensitiveContains(normalizedQuery) ||
                $0.status.title.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }
}
