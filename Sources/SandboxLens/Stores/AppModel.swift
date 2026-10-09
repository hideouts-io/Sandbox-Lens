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
    @Published private(set) var isExporting = false
    @Published private(set) var runtimeSpecimenExportURL: URL?
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

    var visibleSelectedComparison: ProfileComparison? {
        switch selectedDestination {
        case .overview, .baselines, .learn:
            return nil
        case .allProfiles, .changed, .missing, .unexpected:
            guard let selectedComparisonID else {
                return nil
            }
            return filteredComparisons.first { $0.id == selectedComparisonID }
        }
    }

    var exactBaselineSelected: Bool {
        guard let baseline = selectedBaseline, let systemIdentity else {
            return false
        }
        return baseline.productVersion == systemIdentity.productVersion &&
            baseline.buildVersion == systemIdentity.buildVersion
    }

    var canExportRuntimeResearchSpecimen: Bool {
        !isScanning && !isExporting && scanResult != nil &&
            systemIdentity != nil && visibleSelectedComparison?.scanned != nil
    }

    var runtimeSpecimenExportHelp: String {
        if isScanning {
            return "Wait for the scan to finish before exporting."
        }
        if isExporting {
            return "A runtime research specimen export is already in progress."
        }
        guard scanResult != nil else {
            return "Scan profiles before exporting a runtime research specimen."
        }
        guard systemIdentity != nil else {
            return "The scanning host's macOS version and build are unavailable."
        }
        guard let comparison = visibleSelectedComparison else {
            return "Open a profile list and select a visible scanned profile before exporting."
        }
        guard let scanned = comparison.scanned else {
            return "This baseline-only row has no original profile bytes to export."
        }
        return "Copy \(scanned.fileName) and its static evidence into a new folder for external research."
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

    func exportRuntimeResearchSpecimen() async {
        guard canExportRuntimeResearchSpecimen,
              let comparison = visibleSelectedComparison,
              let scanned = comparison.scanned,
              let scan = scanResult,
              let host = systemIdentity else {
            errorMessage = runtimeSpecimenExportHelp
            return
        }
        let baseline = selectedBaseline
        isExporting = true
        errorMessage = nil
        runtimeSpecimenExportURL = nil
        defer {
            isExporting = false
        }

        do {
            let app = try RuntimeSpecimenAppIdentity.read(bundle: .main)
            guard let destination = try await chooseRuntimeSpecimenDestination(profile: scanned, baseline: baseline) else {
                return
            }
            let exportedAt = Date()
            try await Task.detached(priority: .userInitiated) {
                try RuntimeSpecimenExporter.export(
                    comparison: comparison,
                    scan: scan,
                    baseline: baseline,
                    host: host,
                    app: app,
                    destination: destination,
                    exportedAt: exportedAt
                )
            }.value
            runtimeSpecimenExportURL = destination
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func chooseRuntimeSpecimenDestination(profile: ScannedProfile, baseline: BaselineRelease?) async throws -> URL? {
        let panel = NSSavePanel()
        let validator = RuntimeSpecimenSavePanelDelegate()
        panel.delegate = validator
        panel.title = "Export Runtime Research Specimen"
        panel.prompt = "Export"
        panel.nameFieldLabel = "Specimen folder:"
        panel.nameFieldStringValue = "\(URL(fileURLWithPath: profile.fileName).deletingPathExtension().lastPathComponent)-runtime-specimen"
        panel.message = "Enter a new folder name. This export copies static evidence only."
        panel.accessoryView = runtimeSpecimenAccessory(profile: profile, baseline: baseline)
        panel.canCreateDirectories = true

        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            panel.begin { response in
                withExtendedLifetime(validator) {
                    continuation.resume(returning: response)
                }
            }
        }
        switch response {
        case .cancel:
            return nil
        case .OK:
            guard let url = panel.url else {
                throw RuntimeSpecimenSavePanelError.noDestination
            }
            return url
        default:
            throw RuntimeSpecimenSavePanelError.panelFailed(response: response.rawValue)
        }
    }

    private func runtimeSpecimenAccessory(profile: ScannedProfile, baseline: BaselineRelease?) -> NSView {
        let baselineDescription = baseline.map {
            "\($0.displayName)\nBuild: \($0.buildVersion)"
        } ?? "No baseline selected"
        let fields: [NSView] = [
            runtimeSpecimenAccessoryField(title: "Source profile", value: profile.fileURL.path, identifier: "export.sourcePath"),
            runtimeSpecimenAccessoryField(title: "Scanned SHA-256", value: profile.sha256, identifier: "export.sourceSHA256"),
            runtimeSpecimenAccessoryField(title: "Comparison baseline", value: baselineDescription, identifier: "export.baseline")
        ]
        let accessory = NSStackView(views: fields)
        accessory.orientation = .vertical
        accessory.alignment = .leading
        accessory.spacing = 12
        accessory.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        accessory.translatesAutoresizingMaskIntoConstraints = false
        accessory.widthAnchor.constraint(equalToConstant: 480).isActive = true
        for field in fields {
            field.widthAnchor.constraint(equalTo: accessory.widthAnchor).isActive = true
        }
        accessory.setFrameSize(accessory.fittingSize)
        return accessory
    }

    private func runtimeSpecimenAccessoryField(title: String, value: String, identifier: String) -> NSView {
        let heading = NSTextField(labelWithString: title)
        heading.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let content = NSTextField(wrappingLabelWithString: value)
        content.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        content.isEditable = false
        content.isSelectable = true
        content.preferredMaxLayoutWidth = 480
        content.lineBreakMode = .byCharWrapping
        content.setContentCompressionResistancePriority(.required, for: .vertical)
        content.setAccessibilityIdentifier(identifier)
        let field = NSStackView(views: [heading, content])
        field.orientation = .vertical
        field.alignment = .leading
        field.spacing = 3
        field.translatesAutoresizingMaskIntoConstraints = false
        content.widthAnchor.constraint(equalTo: field.widthAnchor).isActive = true
        return field
    }

    private func scan(roots: [ScanRoot]) async {
        isScanning = true
        errorMessage = nil
        runtimeSpecimenExportURL = nil
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

@MainActor
private final class RuntimeSpecimenSavePanelDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, validate url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            throw RuntimeSpecimenSavePanelError.destinationExists(path: url.path)
        }
    }
}

private enum RuntimeSpecimenSavePanelError: LocalizedError {
    case destinationExists(path: String)
    case noDestination
    case panelFailed(response: Int)

    var errorDescription: String? {
        switch self {
        case .destinationExists(let path):
            "The specimen destination already exists: \(path). Choose a new folder name; existing items cannot be replaced."
        case .noDestination:
            "The export picker did not return a destination folder. Choose a new folder name and try again."
        case .panelFailed(let response):
            "The export picker could not complete the selection (panel response \(response)). Try exporting again."
        }
    }
}
