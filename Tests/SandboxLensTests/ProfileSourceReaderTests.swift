import XCTest
@testable import SandboxLens

final class ProfileSourceReaderTests: XCTestCase {
    func testReadsScannedSourceTextFromImportedFolder() async throws {
        let root = try temporaryDirectory()
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
        }
        let nested = root.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let profileURL = nested.appendingPathComponent("sample.sb")
        let source = "(version 1)\n(deny default)\n"
        try Data(source.utf8).write(to: profileURL)

        let scan = try await ProfileScanner().scan(roots: [ProfileScanner.importedRoot(url: root)])
        let profile = try XCTUnwrap(scan.profiles.first)

        XCTAssertEqual(try ProfileSourceReader.read(profile: profile, scan: scan), source)
    }

    func testRejectsChangedAndMissingSourceAfterScan() async throws {
        let root = try temporaryDirectory()
        addTeardownBlock {
            try FileManager.default.removeItem(at: root)
        }
        let profileURL = root.appendingPathComponent("sample.sb")
        try Data("(version 1)\n(deny default)\n".utf8).write(to: profileURL)
        let scan = try await ProfileScanner().scan(roots: [ProfileScanner.importedRoot(url: root)])
        let profile = try XCTUnwrap(scan.profiles.first)

        try Data("(version 1)\n(allow default)\n".utf8).write(to: profileURL)
        XCTAssertThrowsError(try ProfileSourceReader.read(profile: profile, scan: scan)) { error in
            guard case .sourceChanged = error as? ProfileSourceReaderError else {
                return XCTFail("Expected a changed source error: \(error)")
            }
        }

        try FileManager.default.removeItem(at: profileURL)
        XCTAssertThrowsError(try ProfileSourceReader.read(profile: profile, scan: scan)) { error in
            guard case .sourceUnavailable = error as? ProfileSourceReaderError else {
                return XCTFail("Expected an unavailable source error: \(error)")
            }
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandboxLensSourceReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
