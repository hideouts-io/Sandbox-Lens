import XCTest
@testable import SandboxLens

final class ProfileScannerTests: XCTestCase {
    func testRejectsBroadSystemFolderSelection() {
        XCTAssertThrowsError(
            try ProfileScanner.validateImportedFolderURL(
                url: URL(fileURLWithPath: "/System/Library", isDirectory: true)
            )
        )
    }

    func testAllowsDirectSandboxProfileFolderSelection() throws {
        XCTAssertNoThrow(
            try ProfileScanner.validateImportedFolderURL(
                url: URL(
                    fileURLWithPath: "/System/Library/Sandbox/Profiles",
                    isDirectory: true
                )
            )
        )
    }

    func testRecursivelyScansReadOnlyProfile() async throws {
        let root = try temporaryDirectory()
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
        }
        let nested = root.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let profile = nested.appendingPathComponent("synthetic.sb")
        try Data("(version 1)\n(deny default)\n".utf8).write(to: profile)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: profile.path)

        let result = try await ProfileScanner().scan(
            roots: [ProfileScanner.importedRoot(url: root)]
        )

        XCTAssertEqual(result.profiles.count, 1)
        XCTAssertEqual(result.profiles[0].fileName, "synthetic.sb")
        XCTAssertTrue(result.profiles[0].analysis.hasDenyDefault)
    }

    func testRejectsFolderWithoutProfiles() async throws {
        let root = try temporaryDirectory()
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
        }

        do {
            _ = try await ProfileScanner().scan(
                roots: [ProfileScanner.importedRoot(url: root)]
            )
            XCTFail("Expected an empty profile folder to be rejected.")
        } catch let error as ProfileScannerError {
            guard case .noProfilesFound(let path) = error else {
                return XCTFail("Unexpected scanner error: \(error)")
            }
            XCTAssertEqual(path, root.path)
        }
    }

    func testRejectsOversizedProfile() async throws {
        let root = try temporaryDirectory()
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
        }
        let profile = root.appendingPathComponent("oversized.sb")
        let data = Data(repeating: 0x20, count: ProfileScanner.maximumProfileSizeBytes + 1)
        try data.write(to: profile)

        do {
            _ = try await ProfileScanner().scan(
                roots: [ProfileScanner.importedRoot(url: root)]
            )
            XCTFail("Expected an oversized profile to be rejected.")
        } catch let error as ProfileScannerError {
            guard case .profileTooLarge(let path, let sizeBytes, let maximumBytes) = error else {
                return XCTFail("Unexpected scanner error: \(error)")
            }
            XCTAssertEqual(
                URL(fileURLWithPath: path).resolvingSymlinksInPath(),
                profile.resolvingSymlinksInPath()
            )
            XCTAssertEqual(sizeBytes, ProfileScanner.maximumProfileSizeBytes + 1)
            XCTAssertEqual(maximumBytes, ProfileScanner.maximumProfileSizeBytes)
        }
    }

    func testRejectsProfileSymlinkThatEscapesSelectedFolder() async throws {
        let root = try temporaryDirectory()
        let outsideRoot = try temporaryDirectory()
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
            try FileManager.default.removeItem(at: outsideRoot)
        }
        let externalProfile = outsideRoot.appendingPathComponent("external.sb")
        try Data("(version 1)\n(deny default)\n".utf8).write(to: externalProfile)
        let linkedProfile = root.appendingPathComponent("linked.sb")
        try FileManager.default.createSymbolicLink(
            at: linkedProfile,
            withDestinationURL: externalProfile
        )

        do {
            _ = try await ProfileScanner().scan(
                roots: [ProfileScanner.importedRoot(url: root)]
            )
            XCTFail("Expected an external symbolic-link target to be rejected.")
        } catch let error as ProfileScannerError {
            guard case .pathEscapedRoot(let file, let reportedRoot) = error else {
                return XCTFail("Unexpected scanner error: \(error)")
            }
            XCTAssertEqual(URL(fileURLWithPath: file).lastPathComponent, "external.sb")
            XCTAssertEqual(
                URL(fileURLWithPath: reportedRoot).lastPathComponent,
                root.lastPathComponent
            )
        }
    }

    func testReportsProfileThatDisappearsBeforeRead() async throws {
        let root = try temporaryDirectory()
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
        }
        let missingTarget = root.appendingPathComponent("missing-target.sb")
        let linkedProfile = root.appendingPathComponent("disappeared.sb")
        try FileManager.default.createSymbolicLink(
            at: linkedProfile,
            withDestinationURL: missingTarget
        )

        do {
            _ = try await ProfileScanner().scan(
                roots: [ProfileScanner.importedRoot(url: root)]
            )
            XCTFail("Expected a missing symbolic-link target to produce a read error.")
        } catch let error as ProfileScannerError {
            guard case .readFailed(let path, _) = error else {
                return XCTFail("Unexpected scanner error: \(error)")
            }
            XCTAssertEqual(URL(fileURLWithPath: path).lastPathComponent, "disappeared.sb")
        }
    }

    func testReportsPermissionDeniedProfile() async throws {
        let root = try temporaryDirectory()
        let profile = root.appendingPathComponent("protected.sb")
        addTeardownBlock {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: profile.path
            )
            try FileManager.default.removeItem(at: root)
        }
        try Data("(version 1)\n(deny default)\n".utf8).write(to: profile)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: profile.path
        )

        do {
            _ = try await ProfileScanner().scan(
                roots: [ProfileScanner.importedRoot(url: root)]
            )
            XCTFail("Expected an unreadable profile to produce a read error.")
        } catch let error as ProfileScannerError {
            guard case .readFailed(let path, _) = error else {
                return XCTFail("Unexpected scanner error: \(error)")
            }
            XCTAssertEqual(URL(fileURLWithPath: path).lastPathComponent, "protected.sb")
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandboxLensTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
