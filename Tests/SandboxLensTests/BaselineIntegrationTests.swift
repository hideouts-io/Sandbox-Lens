import XCTest
@testable import SandboxLens

final class BaselineIntegrationTests: XCTestCase {
    func testBundledCatalogLoadsAndContainsSourcedSnapshots() throws {
        let catalog = try BaselineRepository.loadBundledCatalog()

        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertEqual(catalog.releases.count, 22)
        XCTAssertEqual(catalog.releases.reduce(0) { $0 + $1.profileCount }, 5_342)
        XCTAssertTrue(catalog.releases.contains { release in
            release.productVersion == "10.9.5" && release.buildVersion == "13F34"
        })
        XCTAssertTrue(catalog.releases.contains { release in
            release.productVersion == "12.6" && release.buildVersion == "21G115"
        })
        XCTAssertTrue(catalog.releases.contains { release in
            release.productVersion == "26.6.2" && release.buildVersion == "25G83"
        })
        XCTAssertTrue(catalog.releases.contains { release in
            release.productVersion == "26.7" && release.buildVersion == "25G229"
        })
        XCTAssertTrue(catalog.releases.contains { release in
            release.productVersion == "27.0" && release.buildVersion == "26A428"
        })
        XCTAssertTrue(catalog.releases.allSatisfy { !$0.profiles.isEmpty })
    }
}
