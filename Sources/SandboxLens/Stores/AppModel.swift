import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var catalog: BaselineCatalog?
    @Published private(set) var systemIdentity: SystemIdentity?
    @Published private(set) var scanResult: ScanResult?
    @Published private(set) var comparisons: [ProfileComparison] = []
    @Published var selectedBaselineID: String? {
        didSet {
            recomputeComparisons()
        }
    }
    @Published var selectedComparisonID: String?
    @Published var selectedDestination: SidebarDestination = .overview
    @Published var searchText = ""
    @Published private(set) var isScanning = false
    @Published var errorMessage: String?

    private let scanner = ProfileScanner()
    private var didBootstrap = false

    init() {
        selectedBaselineID = nil
        selectedComparisonID = nil
    }

    var releases: [BaselineRelease] {
        catalog?.releases.sorted(by: releaseSort) ?? []
    }

    var selectedBaseline: BaselineRelease? {
        guard let selectedBaselineID else {
            return nil
        }
        return catalog?.releases.first { $0.id == selectedBaselineID }
    }

    var selectedComparison: ProfileComparison? {
        guard let selectedComparisonID else {
            return nil
        }
        return comparisons.first { $0.id == selectedComparisonID }
    }

    var filteredComparisons: [ProfileComparison] {
        ComparisonFilter.apply(
            comparisons: comparisons,
            destination: selectedDestination,
            query: searchText
        )
    }

    var exactBaselineSelected: Bool {
        guard let baseline = selectedBaseline, let systemIdentity else {
            return false
        }
        return baseline.productVersion == systemIdentity.productVersion &&
            baseline.buildVersion == systemIdentity.buildVersion
    }

    func bootstrap() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true
        do {
            let loadedCatalog = try BaselineRepository.loadBundledCatalog()
            let identity = try SystemIdentityReader.current()
            catalog = loadedCatalog
            systemIdentity = identity
            selectedBaselineID = bestBaselineID(catalog: loadedCatalog, identity: identity)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scanThisMac() async {
        await scan(roots: ProfileScanner.systemRoots())
    }

    func scanFolder(url: URL) async {
        do {
            try ProfileScanner.validateImportedFolderURL(url: url)
            await scan(roots: [ProfileScanner.importedRoot(url: url)])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func count(status: ComparisonStatus) -> Int {
        comparisons.lazy.filter { $0.status == status }.count
    }

    func selectFirstVisibleComparison() {
        let visible = filteredComparisons
        if let selectedComparisonID,
           visible.contains(where: { $0.id == selectedComparisonID }) {
            return
        }
        selectedComparisonID = visible.first?.id
    }

    func revealSelectedProfile() {
        guard let url = selectedComparison?.scanned?.fileURL else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func scan(roots: [ScanRoot]) async {
        isScanning = true
        errorMessage = nil
        defer {
            isScanning = false
        }

        do {
            scanResult = try await scanner.scan(roots: roots)
            recomputeComparisons()
            selectedDestination = .overview
            selectedComparisonID = comparisons.first(where: { $0.status != .match })?.id ?? comparisons.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recomputeComparisons() {
        guard let scanResult else {
            comparisons = []
            selectedComparisonID = nil
            return
        }

        if let selectedBaseline {
            comparisons = ComparisonEngine.compare(
                scannedProfiles: scanResult.profiles,
                baseline: selectedBaseline
            )
        } else {
            comparisons = ComparisonEngine.unverified(scannedProfiles: scanResult.profiles)
        }
        selectFirstVisibleComparison()
    }

    private func bestBaselineID(catalog: BaselineCatalog, identity: SystemIdentity) -> String? {
        if let exact = catalog.releases.first(where: {
            $0.productVersion == identity.productVersion && $0.buildVersion == identity.buildVersion
        }) {
            return exact.id
        }

        let currentMajor = Int(identity.productVersion.split(separator: ".").first ?? "")
        return catalog.releases
            .filter { $0.majorVersion == currentMajor && !$0.isBeta }
            .sorted(by: releaseSort)
            .first?.id
    }

    private func releaseSort(_ left: BaselineRelease, _ right: BaselineRelease) -> Bool {
        let leftParts = numericVersionParts(left.productVersion)
        let rightParts = numericVersionParts(right.productVersion)
        if leftParts != rightParts {
            return leftParts.lexicographicallyPrecedes(rightParts) { first, second in
                first > second
            }
        }
        return left.buildVersion.localizedStandardCompare(right.buildVersion) == .orderedDescending
    }

    private func numericVersionParts(_ version: String) -> [Int] {
        version.split(separator: ".").map { component in
            Int(component.prefix(while: { $0.isNumber })) ?? -1
        }
    }
}
