import XCTest
@testable import SandboxLens

final class ComparisonFilterTests: XCTestCase {
    func testFiltersByFindingCategory() {
        let comparisons = [
            comparison(path: "Profiles/changed.sb", status: .changed),
            comparison(path: "Profiles/missing.sb", status: .missing),
            comparison(path: "Profiles/additional.sb", status: .unexpected)
        ]

        let filtered = ComparisonFilter.apply(
            comparisons: comparisons,
            destination: .changed,
            query: ""
        )

        XCTAssertEqual(filtered.map(\.fileName), ["changed.sb"])
    }

    func testSearchesFilenamePathAndStatusWithoutCaseSensitivity() {
        let comparisons = [
            comparison(path: "System/Library/Sandbox/Profiles/Camera.sb", status: .changed),
            comparison(path: "usr/share/sandbox/network.sb", status: .missing)
        ]

        let filenameMatch = ComparisonFilter.apply(
            comparisons: comparisons,
            destination: .allProfiles,
            query: "camera"
        )
        let pathMatch = ComparisonFilter.apply(
            comparisons: comparisons,
            destination: .allProfiles,
            query: "USR/SHARE"
        )
        let statusMatch = ComparisonFilter.apply(
            comparisons: comparisons,
            destination: .allProfiles,
            query: "expected but missing"
        )

        XCTAssertEqual(filenameMatch.map(\.fileName), ["Camera.sb"])
        XCTAssertEqual(pathMatch.map(\.fileName), ["network.sb"])
        XCTAssertEqual(statusMatch.map(\.fileName), ["network.sb"])
    }

    private func comparison(path: String, status: ComparisonStatus) -> ProfileComparison {
        ProfileComparison(
            id: path,
            relativePath: path,
            fileName: URL(fileURLWithPath: path).lastPathComponent,
            status: status,
            method: .none,
            scanned: nil,
            baseline: nil,
            changes: []
        )
    }
}
