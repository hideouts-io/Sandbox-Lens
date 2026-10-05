import CryptoKit
import XCTest
@testable import SandboxLens

final class RuntimeSpecimenExporterTests: XCTestCase {
    func testExportsExactBytesWithChecksumsAndSeparateProvenance() async throws {
        let root = try temporaryDirectory()
        let bytes = Data("\u{FEFF}(version 1)\r\n(import \"support.sb\")\r\n; café 日本語\r\n(deny default)\r\n".utf8)
        let fixture = try await scannedFixture(root: root, bytes: bytes)
        let profile = try XCTUnwrap(fixture.scan.profiles.first)
        let baseline = baselineRelease(profile: profile)
        let comparison = try XCTUnwrap(
            ComparisonEngine.compare(scannedProfiles: fixture.scan.profiles, baseline: baseline).first
        )
        let destination = root.appendingPathComponent("specimen", isDirectory: true)
        let host = SystemIdentity(productVersion: "26.1", buildVersion: "HOST-BUILD")
        let app = RuntimeSpecimenAppIdentity(
            bundleIdentifier: "io.hideouts.SandboxLens",
            version: "1.2.3",
            build: "45"
        )
        let exportedAt = Date(timeIntervalSince1970: 1_720_000_000.125)

        try RuntimeSpecimenExporter.export(
            comparison: comparison,
            scan: fixture.scan,
            baseline: baseline,
            host: host,
            app: app,
            destination: destination,
            exportedAt: exportedAt
        )

        let fileNames = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        XCTAssertEqual(Set(fileNames), ["profile.sb", "manifest.json", "sha256.txt", "README.txt"])
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("profile.sb")), bytes)
        XCTAssertEqual(try Data(contentsOf: fixture.source), bytes)
        let checksums = try String(contentsOf: destination.appendingPathComponent("sha256.txt"), encoding: .utf8)
        let lines = checksums.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        for fileName in ["profile.sb", "manifest.json", "README.txt"] {
            let emitted = try Data(contentsOf: destination.appendingPathComponent(fileName))
            let digest = SHA256.hash(data: emitted).map { String(format: "%02x", $0) }.joined()
            XCTAssertTrue(lines.contains("\(digest)  \(fileName)"))
        }
        XCTAssertTrue(checksums.hasSuffix("\n"))

        let manifest = try readManifest(destination: destination)
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.exportedAt, exportedAt)
        XCTAssertEqual(manifest.app.bundleIdentifier, app.bundleIdentifier)
        XCTAssertEqual(manifest.app.version, app.version)
        XCTAssertEqual(manifest.app.build, app.build)
        XCTAssertEqual(manifest.scanningHost, host)
        XCTAssertEqual(manifest.scan.startedAt.timeIntervalSince1970, fixture.scan.startedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(manifest.scan.completedAt.timeIntervalSince1970, fixture.scan.completedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(manifest.source.fileURL, fixture.source)
        XCTAssertEqual(manifest.source.scanRootURL, root)
        XCTAssertEqual(manifest.source.relativePath, profile.relativePath)
        XCTAssertEqual(manifest.source.fileName, profile.fileName)
        XCTAssertEqual(manifest.source.sizeBytes, bytes.count)
        XCTAssertEqual(manifest.source.sha256, profile.sha256)
        XCTAssertNil(manifest.source.originatingSystem)
        XCTAssertFalse(manifest.source.isSymbolicLink)
        XCTAssertNil(manifest.source.symbolicLinkTarget)
        XCTAssertEqual(manifest.comparison.status, .match)
        XCTAssertEqual(manifest.comparison.method, .exactPath)
        XCTAssertEqual(manifest.comparison.matchedBaseline, comparison.baseline)
        let selectedBaseline = try XCTUnwrap(manifest.selectedBaseline)
        XCTAssertEqual(selectedBaseline.id, baseline.id)
        XCTAssertEqual(selectedBaseline.displayName, baseline.displayName)
        XCTAssertEqual(selectedBaseline.productVersion, baseline.productVersion)
        XCTAssertEqual(selectedBaseline.buildVersion, baseline.buildVersion)
        XCTAssertEqual(selectedBaseline.releaseChannel, baseline.releaseChannel)
        XCTAssertEqual(selectedBaseline.sourceName, baseline.sourceName)
        XCTAssertEqual(selectedBaseline.sourceURL, baseline.sourceURL)
        XCTAssertEqual(selectedBaseline.sourceCommit, baseline.sourceCommit)
        XCTAssertEqual(selectedBaseline.confidence, baseline.confidence)
        XCTAssertEqual(selectedBaseline.notes, baseline.notes)
        XCTAssertNotEqual(selectedBaseline.buildVersion, manifest.scanningHost.buildVersion)
        XCTAssertEqual(manifest.staticAnalysis.imports, ["support.sb"])
        XCTAssertEqual(manifest.runtimeObservation, .notPerformed)
        XCTAssertEqual(manifest.policyWitnessReference.revision.count, 40)
    }

    func testExportsUnavailableFactsAsExplicitNull() async throws {
        let root = try temporaryDirectory()
        let fixture = try await scannedFixture(root: root, bytes: Data("(version 1)\n(deny default)\n".utf8))
        let destination = root.appendingPathComponent("specimen", isDirectory: true)

        try exportUnverified(fixture: fixture, destination: destination)

        let manifest = try readManifest(destination: destination)
        XCTAssertNil(manifest.selectedBaseline)
        XCTAssertNil(manifest.comparison.matchedBaseline)
        XCTAssertEqual(manifest.comparison.status, .unverified)
        XCTAssertEqual(manifest.comparison.method, .none)
        let data = try Data(contentsOf: destination.appendingPathComponent("manifest.json"))
        let unavailable = try JSONDecoder().decode(ExplicitUnavailableFacts.self, from: data)
        XCTAssertTrue(unavailable.selectedBaselineIsNull)
        XCTAssertTrue(unavailable.source.originatingSystemIsNull)
        XCTAssertTrue(unavailable.source.symbolicLinkTargetIsNull)
        XCTAssertTrue(unavailable.comparison.matchedBaselineIsNull)
        XCTAssertTrue(unavailable.app.bundleIdentifierIsNull)
        XCTAssertTrue(unavailable.app.versionIsNull)
        XCTAssertTrue(unavailable.app.buildIsNull)
    }

    func testRejectsBaselineOnlySelectionWithoutCreatingOutput() async throws {
        let root = try temporaryDirectory()
        let fixture = try await scannedFixture(root: root, bytes: Data("(version 1)\n".utf8))
        let profile = try XCTUnwrap(fixture.scan.profiles.first)
        let baseline = baselineRelease(profile: profile)
        let comparison = try XCTUnwrap(
            ComparisonEngine.compare(scannedProfiles: [], baseline: baseline).first
        )
        let destination = root.appendingPathComponent("specimen", isDirectory: true)

        XCTAssertThrowsError(try RuntimeSpecimenExporter.export(
            comparison: comparison,
            scan: fixture.scan,
            baseline: baseline,
            host: SystemIdentity(productVersion: "26.1", buildVersion: "HOST-BUILD"),
            app: RuntimeSpecimenAppIdentity(bundleIdentifier: nil, version: nil, build: nil),
            destination: destination,
            exportedAt: Date(timeIntervalSince1970: 1_720_000_000)
        )) { error in
            guard case RuntimeSpecimenError.sourceUnavailable = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["synthetic.sb"])
    }

    func testRejectsChangedDisappearedAndNonregularSourcesWithoutCreatingOutput() async throws {
        let root = try temporaryDirectory()
        let fixture = try await scannedFixture(root: root, bytes: Data("(version 1)\n(deny default)\n".utf8))
        let destination = root.appendingPathComponent("specimen", isDirectory: true)
        try Data("(version 1)\n(allow default)\n".utf8).write(to: fixture.source)

        XCTAssertThrowsError(try exportUnverified(fixture: fixture, destination: destination)) { error in
            guard case RuntimeSpecimenError.sourceChanged(let path, let expected, let actual) = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
            XCTAssertEqual(path, fixture.source.path)
            XCTAssertNotEqual(expected, actual)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["synthetic.sb"])

        try FileManager.default.removeItem(at: fixture.source)
        XCTAssertThrowsError(try exportUnverified(fixture: fixture, destination: destination))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)

        try FileManager.default.createDirectory(at: fixture.source, withIntermediateDirectories: false)
        XCTAssertThrowsError(try exportUnverified(fixture: fixture, destination: destination)) { error in
            guard case ProfileScannerError.profileNotRegularFile = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["synthetic.sb"])
    }

    func testRejectsSourceSymlinkThatEscapesRootAfterScan() async throws {
        let root = try temporaryDirectory()
        let outside = try temporaryDirectory()
        let bytes = Data("(version 1)\n(deny default)\n".utf8)
        let fixture = try await scannedFixture(root: root, bytes: bytes)
        let externalSource = outside.appendingPathComponent("external.sb")
        try bytes.write(to: externalSource)
        try FileManager.default.removeItem(at: fixture.source)
        try FileManager.default.createSymbolicLink(at: fixture.source, withDestinationURL: externalSource)
        let destination = root.appendingPathComponent("specimen", isDirectory: true)

        XCTAssertThrowsError(try exportUnverified(fixture: fixture, destination: destination)) { error in
            guard case ProfileScannerError.pathEscapedRoot = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["synthetic.sb"])
    }

    func testExportsSourceSymlinkAsRegularFileAndRejectsEqualByteRetargeting() async throws {
        let root = try temporaryDirectory()
        let bytes = Data("(version 1)\n(deny default)\n".utf8)
        let target = root.appendingPathComponent("target.txt")
        try bytes.write(to: target)
        let source = root.appendingPathComponent("synthetic.sb")
        try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: "target.txt")
        let scan = try await ProfileScanner().scan(roots: [ProfileScanner.importedRoot(url: root)])
        let fixture = ExportFixture(source: source, scan: scan)
        let destination = root.appendingPathComponent("specimen", isDirectory: true)

        try exportUnverified(fixture: fixture, destination: destination)

        let exportedProfile = destination.appendingPathComponent("profile.sb")
        let values = try exportedProfile.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        XCTAssertEqual(values.isSymbolicLink, false)
        XCTAssertEqual(values.isRegularFile, true)
        XCTAssertEqual(try Data(contentsOf: exportedProfile), bytes)
        let manifest = try readManifest(destination: destination)
        XCTAssertTrue(manifest.source.isSymbolicLink)
        XCTAssertEqual(manifest.source.symbolicLinkTarget, "target.txt")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: source.path), "target.txt")

        let replacement = root.appendingPathComponent("replacement.txt")
        try bytes.write(to: replacement)
        try FileManager.default.removeItem(at: source)
        try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: "replacement.txt")
        let retargetedDestination = root.appendingPathComponent("retargeted-specimen", isDirectory: true)
        XCTAssertThrowsError(try exportUnverified(fixture: fixture, destination: retargetedDestination)) { error in
            guard case RuntimeSpecimenError.sourceMetadataChanged = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: retargetedDestination.path))
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)), [
            "synthetic.sb", "target.txt", "replacement.txt", "specimen"
        ])
    }

    func testKeepsExistingDestinationUnchanged() async throws {
        let root = try temporaryDirectory()
        let fixture = try await scannedFixture(root: root, bytes: Data("(version 1)\n".utf8))
        let destination = root.appendingPathComponent("specimen", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let sentinel = destination.appendingPathComponent("keep.txt")
        let sentinelBytes = Data("Existing research output\n".utf8)
        try sentinelBytes.write(to: sentinel)

        XCTAssertThrowsError(try exportUnverified(fixture: fixture, destination: destination)) { error in
            guard case RuntimeSpecimenError.destinationExists(let path) = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
            XCTAssertEqual(path, destination.path)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["keep.txt"])
        XCTAssertEqual(try Data(contentsOf: sentinel), sentinelBytes)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)), ["synthetic.sb", "specimen"])
    }

    func testWriteFailureLeavesNoCompletedOutputOrTemporaryFolder() async throws {
        let root = try temporaryDirectory()
        let fixture = try await scannedFixture(root: root, bytes: Data("(version 1)\n".utf8))
        let parent = root.appendingPathComponent("read-only", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        addTeardownBlock {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent.path)
        let destination = parent.appendingPathComponent("specimen", isDirectory: true)

        XCTAssertThrowsError(try exportUnverified(fixture: fixture, destination: destination)) { error in
            guard case RuntimeSpecimenError.writeFailed = error else {
                return XCTFail("Unexpected export error: \(error)")
            }
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandboxLensExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func scannedFixture(root: URL, bytes: Data) async throws -> ExportFixture {
        let source = root.appendingPathComponent("synthetic.sb")
        try bytes.write(to: source)
        let scan = try await ProfileScanner().scan(roots: [ProfileScanner.importedRoot(url: root)])
        return ExportFixture(source: try XCTUnwrap(scan.profiles.first).fileURL, scan: scan)
    }

    private func exportUnverified(fixture: ExportFixture, destination: URL) throws {
        let comparison = try XCTUnwrap(ComparisonEngine.unverified(scannedProfiles: fixture.scan.profiles).first)
        try RuntimeSpecimenExporter.export(
            comparison: comparison,
            scan: fixture.scan,
            baseline: nil,
            host: SystemIdentity(productVersion: "26.1", buildVersion: "HOST-BUILD"),
            app: RuntimeSpecimenAppIdentity(bundleIdentifier: nil, version: nil, build: nil),
            destination: destination,
            exportedAt: Date(timeIntervalSince1970: 1_720_000_000)
        )
    }

    private func readManifest(destination: URL) throws -> RuntimeSpecimenManifest {
        let data = try Data(contentsOf: destination.appendingPathComponent("manifest.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(RuntimeSpecimenManifest.self, from: data)
    }

    private func baselineRelease(profile: ScannedProfile) -> BaselineRelease {
        BaselineRelease(
            id: "synthetic-reference",
            displayName: "macOS synthetic reference",
            productVersion: "12.6",
            buildVersion: "REFERENCE-BUILD",
            releaseChannel: "stable",
            sourceName: "Synthetic integration fixture",
            sourceURL: "https://example.com/reference",
            sourceCommit: "fixture-revision",
            confidence: "synthetic",
            notes: "Synthetic provenance; no originating system is established.",
            profileCount: 1,
            profiles: [BaselineProfile(
                relativePath: profile.relativePath,
                fileName: profile.fileName,
                sha256: profile.sha256,
                sizeBytes: profile.sizeBytes,
                isSymbolicLink: profile.isSymbolicLink,
                symbolicLinkTarget: profile.symbolicLinkTarget,
                analysis: profile.analysis
            )]
        )
    }
}

private struct ExportFixture {
    let source: URL
    let scan: ScanResult
}

private struct ExplicitUnavailableFacts: Decodable {
    let selectedBaselineIsNull: Bool
    let source: Source
    let comparison: Comparison
    let app: App

    private enum CodingKeys: String, CodingKey {
        case selectedBaseline, source, comparison, app
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedBaselineIsNull = try container.decodeNil(forKey: .selectedBaseline)
        source = try container.decode(Source.self, forKey: .source)
        comparison = try container.decode(Comparison.self, forKey: .comparison)
        app = try container.decode(App.self, forKey: .app)
    }

    struct Source: Decodable {
        let originatingSystemIsNull: Bool
        let symbolicLinkTargetIsNull: Bool

        private enum CodingKeys: String, CodingKey {
            case originatingSystem, symbolicLinkTarget
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            originatingSystemIsNull = try container.decodeNil(forKey: .originatingSystem)
            symbolicLinkTargetIsNull = try container.decodeNil(forKey: .symbolicLinkTarget)
        }
    }

    struct Comparison: Decodable {
        let matchedBaselineIsNull: Bool

        private enum CodingKeys: String, CodingKey {
            case matchedBaseline
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            matchedBaselineIsNull = try container.decodeNil(forKey: .matchedBaseline)
        }
    }

    struct App: Decodable {
        let bundleIdentifierIsNull: Bool
        let versionIsNull: Bool
        let buildIsNull: Bool

        private enum CodingKeys: String, CodingKey {
            case bundleIdentifier, version, build
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bundleIdentifierIsNull = try container.decodeNil(forKey: .bundleIdentifier)
            versionIsNull = try container.decodeNil(forKey: .version)
            buildIsNull = try container.decodeNil(forKey: .build)
        }
    }
}
