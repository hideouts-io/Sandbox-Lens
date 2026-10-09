import XCTest
@testable import SandboxLens

@MainActor
final class RuntimeSpecimenSelectionTests: XCTestCase {
    func testExportRequiresAVisibleSelectedProfileAndKeepsTheScanWhenNavigating() async throws {
        let root = try temporaryDirectory()
        let model = try await scannedModel(root: root)
        let scan = try XCTUnwrap(model.scanResult)
        let selectedID = try XCTUnwrap(model.selectedComparisonID)
        XCTAssertNotNil(model.selectedComparison?.scanned)
        XCTAssertEqual(model.selectedDestination, .overview)
        XCTAssertNil(model.visibleSelectedComparison)
        XCTAssertFalse(model.canExportRuntimeResearchSpecimen)

        model.selectedDestination = .allProfiles
        XCTAssertEqual(model.visibleSelectedComparison?.id, selectedID)
        XCTAssertTrue(model.canExportRuntimeResearchSpecimen)

        for destination in [SidebarDestination.overview, .baselines, .learn] {
            model.selectedDestination = destination
            XCTAssertNil(model.visibleSelectedComparison)
            XCTAssertFalse(model.canExportRuntimeResearchSpecimen)
            XCTAssertEqual(model.selectedComparisonID, selectedID)
            XCTAssertEqual(model.scanResult?.profiles, scan.profiles)
            XCTAssertEqual(model.scanResult?.roots, scan.roots)
            XCTAssertEqual(model.scanResult?.startedAt, scan.startedAt)
            XCTAssertEqual(model.scanResult?.completedAt, scan.completedAt)
        }

        model.selectedDestination = .allProfiles
        XCTAssertEqual(model.visibleSelectedComparison?.id, selectedID)
        XCTAssertTrue(model.canExportRuntimeResearchSpecimen)
    }

    func testSearchImmediatelyDisablesHiddenSelectionBeforeSelectingTheMatchingRow() async throws {
        let root = try temporaryDirectory()
        let model = try await scannedModel(root: root)
        model.selectedDestination = .allProfiles
        let alpha = try XCTUnwrap(model.comparisons.first { $0.fileName == "runtime-selection-alpha.sb" })
        let beta = try XCTUnwrap(model.comparisons.first { $0.fileName == "runtime-selection-beta.sb" })
        model.selectedComparisonID = alpha.id
        XCTAssertTrue(model.canExportRuntimeResearchSpecimen)

        model.searchText = "runtime-selection-beta.sb"

        XCTAssertEqual(model.filteredComparisons.map(\.id), [beta.id])
        XCTAssertEqual(model.selectedComparisonID, alpha.id)
        XCTAssertNil(model.visibleSelectedComparison)
        XCTAssertFalse(model.canExportRuntimeResearchSpecimen)

        model.selectedComparisonID = beta.id
        XCTAssertEqual(model.visibleSelectedComparison?.id, beta.id)
        XCTAssertTrue(model.canExportRuntimeResearchSpecimen)

        model.searchText = "absent-profile.sb"
        XCTAssertTrue(model.filteredComparisons.isEmpty)
        XCTAssertEqual(model.selectedComparisonID, beta.id)
        XCTAssertNil(model.visibleSelectedComparison)
        XCTAssertFalse(model.canExportRuntimeResearchSpecimen)
    }

    func testVisibleBaselineOnlyMissingRowCannotExport() async throws {
        let root = try temporaryDirectory()
        let model = try await scannedModel(root: root)
        let baseline = try XCTUnwrap(model.releases.first {
            $0.productVersion == "12.6" && $0.buildVersion == "21G115"
        })
        model.selectedBaselineID = baseline.id
        model.selectedDestination = .missing
        let missing = try XCTUnwrap(model.filteredComparisons.first)
        XCTAssertEqual(missing.status, .missing)
        XCTAssertNotNil(missing.baseline)
        XCTAssertNil(missing.scanned)
        model.selectedComparisonID = missing.id

        XCTAssertEqual(model.visibleSelectedComparison?.id, missing.id)
        XCTAssertFalse(model.canExportRuntimeResearchSpecimen)

        model.selectedDestination = .allProfiles
        XCTAssertEqual(model.visibleSelectedComparison?.id, missing.id)
        XCTAssertFalse(model.canExportRuntimeResearchSpecimen)

        model.selectedDestination = .unexpected
        let scanned = try XCTUnwrap(model.filteredComparisons.first)
        XCTAssertNotNil(scanned.scanned)
        model.selectedComparisonID = scanned.id
        XCTAssertEqual(model.visibleSelectedComparison?.id, scanned.id)
        XCTAssertTrue(model.canExportRuntimeResearchSpecimen)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandboxLensSelectionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func scannedModel(root: URL) async throws -> AppModel {
        try Data("(version 1)\n(deny default)\n".utf8)
            .write(to: root.appendingPathComponent("runtime-selection-alpha.sb"))
        try Data("(version 1)\n(import \"support.sb\")\n".utf8)
            .write(to: root.appendingPathComponent("runtime-selection-beta.sb"))
        let model = AppModel()
        await model.bootstrap()
        XCTAssertNil(model.errorMessage)
        XCTAssertNotNil(model.systemIdentity)
        XCTAssertFalse(model.releases.isEmpty)
        model.selectedBaselineID = nil
        await model.scanFolder(url: root)
        XCTAssertNil(model.errorMessage)
        let scan = try XCTUnwrap(model.scanResult)
        XCTAssertEqual(scan.profiles.count, 2)
        return model
    }
}
