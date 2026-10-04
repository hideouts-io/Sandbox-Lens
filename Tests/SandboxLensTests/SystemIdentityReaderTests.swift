import Foundation
import XCTest
@testable import SandboxLens

final class SystemIdentityReaderTests: XCTestCase {
    func testOmitsZeroPatchVersion() {
        let version = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)

        XCTAssertEqual(SystemIdentityReader.productVersionString(version: version), "27.0")
    }

    func testPreservesNonzeroPatchVersion() {
        let version = OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 2)

        XCTAssertEqual(SystemIdentityReader.productVersionString(version: version), "26.6.2")
    }
}
