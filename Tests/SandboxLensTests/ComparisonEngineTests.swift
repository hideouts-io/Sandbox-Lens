import XCTest
@testable import SandboxLens

final class ComparisonEngineTests: XCTestCase {
    func testClassifiesMatchChangeMissingAndAdditionalProfiles() {
        let neutral = profileAnalysis(globalNetwork: false)
        let networked = profileAnalysis(globalNetwork: true)
        let baseline = BaselineRelease(
            id: "test-release",
            displayName: "macOS Test",
            productVersion: "1.0",
            buildVersion: "TEST",
            releaseChannel: "stable",
            sourceName: "Test fixture",
            sourceURL: "https://example.com",
            sourceCommit: "fixture",
            confidence: "test",
            notes: "Integration fixture",
            profileCount: 3,
            profiles: [
                baselineProfile(path: "usr/share/sandbox/match.sb", hash: String(repeating: "a", count: 64), analysis: neutral),
                baselineProfile(path: "usr/share/sandbox/change.sb", hash: String(repeating: "b", count: 64), analysis: neutral),
                baselineProfile(path: "usr/share/sandbox/missing.sb", hash: String(repeating: "c", count: 64), analysis: neutral)
            ]
        )
        let scanned = [
            scannedProfile(path: "usr/share/sandbox/match.sb", hash: String(repeating: "a", count: 64), analysis: neutral),
            scannedProfile(path: "usr/share/sandbox/change.sb", hash: String(repeating: "d", count: 64), analysis: networked),
            scannedProfile(path: "usr/share/sandbox/additional.sb", hash: String(repeating: "e", count: 64), analysis: neutral)
        ]

        let comparisons = ComparisonEngine.compare(scannedProfiles: scanned, baseline: baseline)

        XCTAssertEqual(comparisons.filter { $0.status == .match }.count, 1)
        XCTAssertEqual(comparisons.filter { $0.status == .changed }.count, 1)
        XCTAssertEqual(comparisons.filter { $0.status == .missing }.count, 1)
        XCTAssertEqual(comparisons.filter { $0.status == .unexpected }.count, 1)
        XCTAssertTrue(
            comparisons.first { $0.status == .changed }?.changes.contains(
                "The scanned file adds broad networking."
            ) == true
        )
    }

    func testDetectsChangedSymbolicLinkMetadataWithMatchingContents() {
        let analysis = profileAnalysis(globalNetwork: false)
        let hash = String(repeating: "a", count: 64)
        let baselineProfile = BaselineProfile(
            relativePath: "usr/share/sandbox/alias.sb",
            fileName: "alias.sb",
            sha256: hash,
            sizeBytes: 100,
            isSymbolicLink: true,
            symbolicLinkTarget: "target.sb",
            analysis: analysis
        )
        let baseline = BaselineRelease(
            id: "symlink-test",
            displayName: "macOS Symlink Test",
            productVersion: "1.0",
            buildVersion: "TEST",
            releaseChannel: "stable",
            sourceName: "Test fixture",
            sourceURL: "https://example.com",
            sourceCommit: "fixture",
            confidence: "test",
            notes: "Integration fixture",
            profileCount: 1,
            profiles: [baselineProfile]
        )
        let scanned = ScannedProfile(
            relativePath: baselineProfile.relativePath,
            fileName: baselineProfile.fileName,
            fileURL: URL(fileURLWithPath: "/usr/share/sandbox/alias.sb"),
            sha256: hash,
            sizeBytes: 100,
            isSymbolicLink: true,
            symbolicLinkTarget: "different.sb",
            analysis: analysis
        )

        let comparisons = ComparisonEngine.compare(scannedProfiles: [scanned], baseline: baseline)

        XCTAssertEqual(comparisons.count, 1)
        XCTAssertEqual(comparisons[0].status, .changed)
        XCTAssertTrue(comparisons[0].changes[0].contains("Symbolic-link target"))
    }

    private func baselineProfile(path: String, hash: String, analysis: ProfileAnalysis) -> BaselineProfile {
        BaselineProfile(
            relativePath: path,
            fileName: URL(fileURLWithPath: path).lastPathComponent,
            sha256: hash,
            sizeBytes: 100,
            isSymbolicLink: false,
            symbolicLinkTarget: nil,
            analysis: analysis
        )
    }

    private func scannedProfile(path: String, hash: String, analysis: ProfileAnalysis) -> ScannedProfile {
        ScannedProfile(
            relativePath: path,
            fileName: URL(fileURLWithPath: path).lastPathComponent,
            fileURL: URL(fileURLWithPath: "/" + path),
            sha256: hash,
            sizeBytes: 100,
            isSymbolicLink: false,
            symbolicLinkTarget: nil,
            analysis: analysis
        )
    }

    private func profileAnalysis(globalNetwork: Bool) -> ProfileAnalysis {
        ProfileAnalysis(
            allowCount: globalNetwork ? 1 : 0,
            denyCount: 1,
            imports: [],
            hasDenyDefault: true,
            hasAllowDefault: false,
            hasGlobalFileRead: false,
            hasGlobalFileWrite: false,
            hasGlobalFileReadWrite: false,
            hasGlobalProcessExec: false,
            hasGlobalNetwork: globalNetwork,
            hasNoSandboxExecution: false
        )
    }
}
