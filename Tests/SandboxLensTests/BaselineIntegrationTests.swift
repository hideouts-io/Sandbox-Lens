import Foundation
import XCTest
@testable import SandboxLens

final class BaselineIntegrationTests: XCTestCase {
    func testBundledCatalogLoadsAndContainsSourcedSnapshots() throws {
        let catalog = try BaselineRepository.loadBundledCatalog()

        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertEqual(catalog.releases.count, 23)
        XCTAssertEqual(catalog.releases.reduce(0) { $0 + $1.profileCount }, 5_953)
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
        XCTAssertTrue(catalog.releases.contains { release in
            release.productVersion == "27.2" && release.buildVersion == "26B5112a"
        })
        XCTAssertTrue(catalog.releases.allSatisfy { !$0.profiles.isEmpty })
        XCTAssertTrue(catalog.releases.allSatisfy { $0.provenance?.id == $0.id })
    }

    func testPreservesNewCaptureAndConflictingHistoricalProvenance() throws {
        let catalog = try BaselineRepository.loadBundledCatalog()
        let local = try XCTUnwrap(catalog.releases.first { $0.id == "macos-27.2-26B5112a" })
        let provenance = try XCTUnwrap(local.provenance)

        XCTAssertEqual(local.profileCount, 611)
        XCTAssertEqual(local.releaseChannel, "unknown")
        XCTAssertEqual(provenance.sourceKind, .localCapture)
        XCTAssertEqual(provenance.attribution, .declaredUnverified)
        XCTAssertEqual(provenance.architecture, "arm64")
        XCTAssertEqual(provenance.collectedAt, "2026-10-19T07:27:20.757415+00:00")
        XCTAssertEqual(provenance.coverage, .recordedPathsOnly)
        XCTAssertEqual(Set(provenance.roots), ["System/Library/Sandbox/Profiles", "usr/share/sandbox"])
        XCTAssertTrue(provenance.evidence.isEmpty)
        XCTAssertTrue(provenance.limitations.contains { $0.contains("no independent immutable Apple host attestation") })
        XCTAssertTrue(provenance.limitations.contains { $0.contains("not independent timestamp attestation") })
        XCTAssertTrue(provenance.limitations.contains { $0.contains("not atomic acquisition") })

        let monterey = try XCTUnwrap(catalog.releases.first { $0.id == "macos-12.6-21G115" }?.provenance)
        XCTAssertEqual(monterey.attribution, .conflicting)
        XCTAssertEqual(monterey.sourceKind, .communitySnapshot)
        XCTAssertNil(monterey.architecture)
        XCTAssertNil(monterey.collectedAt)
        XCTAssertEqual(monterey.roots, ["System/Library/Sandbox/Profiles"])
        XCTAssertEqual(Set(monterey.evidence.map(\.buildVersion)), ["21G115", "21G72"])
        XCTAssertEqual(Set(monterey.evidence.map(\.productVersion)), ["12.6", "12.5"])
        XCTAssertTrue(monterey.limitations.contains { $0.contains("exact profile build is unresolved") })
    }

    func testRejectsCatalogDigestMismatch() throws {
        let resources = try resourceData()
        var catalogData = resources.catalog
        catalogData.append(contentsOf: [0x0A])

        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: catalogData,
            provenanceData: resources.provenance
        )) { error in
            guard case BaselineProvenanceError.catalogHashMismatch = error else {
                return XCTFail("Unexpected resource-pair error: \(error)")
            }
        }
    }

    func testRejectsMissingSnapshotAnnotation() throws {
        let resources = try resourceData()
        var fixture = try JSONDecoder().decode(ProvenanceFixture.self, from: resources.provenance)
        fixture.snapshots.removeLast()

        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: resources.catalog,
            provenanceData: JSONEncoder().encode(fixture)
        )) { error in
            guard case BaselineProvenanceError.incompleteAnnotations = error else {
                return XCTFail("Unexpected incomplete-annotation error: \(error)")
            }
        }
    }

    func testRejectsDuplicateSnapshotAnnotation() throws {
        let resources = try resourceData()
        var fixture = try JSONDecoder().decode(ProvenanceFixture.self, from: resources.provenance)
        fixture.snapshots.append(try XCTUnwrap(fixture.snapshots.first))

        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: resources.catalog,
            provenanceData: JSONEncoder().encode(fixture)
        )) { error in
            guard case BaselineProvenanceError.duplicateSnapshotIdentifier = error else {
                return XCTFail("Unexpected duplicate-annotation error: \(error)")
            }
        }
    }

    func testRejectsUnsupportedProvenanceSchema() throws {
        let resources = try resourceData()
        var fixture = try JSONDecoder().decode(ProvenanceFixture.self, from: resources.provenance)
        fixture.schemaVersion = 3

        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: resources.catalog,
            provenanceData: JSONEncoder().encode(fixture)
        )) { error in
            guard case BaselineProvenanceError.unsupportedSchema(3) = error else {
                return XCTFail("Unexpected provenance-schema error: \(error)")
            }
        }
    }

    func testRejectsUnsupportedAttributionInsteadOfTreatingItAsTrusted() throws {
        let resources = try resourceData()
        let original = try XCTUnwrap(String(data: resources.provenance, encoding: .utf8))
        let invalid = original.replacingOccurrences(of: "\"declared-unverified\"", with: "\"trusted-exact\"")
        XCTAssertNotEqual(original, invalid)

        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: resources.catalog,
            provenanceData: Data(invalid.utf8)
        )) { error in
            guard case BaselineRepositoryError.decodeFailed(let resource, _) = error else {
                return XCTFail("Unexpected attribution error: \(error)")
            }
            XCTAssertEqual(resource, "BaselineProvenance")
        }
    }

    func testRejectsConflictingEvidenceMarkedUnverified() throws {
        let resources = try resourceData()
        let original = try XCTUnwrap(String(data: resources.provenance, encoding: .utf8))
        let invalid = original.replacingOccurrences(of: "\"conflicting\"", with: "\"declared-unverified\"")
        XCTAssertNotEqual(original, invalid)

        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: resources.catalog,
            provenanceData: Data(invalid.utf8)
        )) { error in
            guard case BaselineProvenanceError.invalidAnnotation(let identifier, let field) = error else {
                return XCTFail("Unexpected conflicting-evidence error: \(error)")
            }
            XCTAssertEqual(identifier, "macos-12.6-21G115")
            XCTAssertEqual(field, "unqualified conflicting evidence")
        }
    }

    func testRejectsInvalidCollectionTimestampAndMissingNullableFact() throws {
        let resources = try resourceData()
        let original = try XCTUnwrap(String(data: resources.provenance, encoding: .utf8))
        let invalid = original.replacingOccurrences(
            of: "2026-10-19T07:27:20.757415+00:00",
            with: "2026-10-19 without an offset"
        )
        XCTAssertNotEqual(original, invalid)
        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: resources.catalog,
            provenanceData: Data(invalid.utf8)
        )) { error in
            guard case BaselineProvenanceError.invalidAnnotation(_, "collectedAt") = error else {
                return XCTFail("Unexpected collection-timestamp error: \(error)")
            }
        }

        let missing = original.replacingOccurrences(of: "\"architecture\": null,", with: "")
        XCTAssertNotEqual(original, missing)
        XCTAssertThrowsError(try BaselineRepository.loadCatalog(
            catalogData: resources.catalog,
            provenanceData: Data(missing.utf8)
        )) { error in
            guard case BaselineRepositoryError.decodeFailed(let resource, _) = error else {
                return XCTFail("Unexpected missing-nullable-fact error: \(error)")
            }
            XCTAssertEqual(resource, "BaselineProvenance")
        }
    }

    private func resourceData() throws -> (catalog: Data, provenance: Data) {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SandboxLens/Resources", isDirectory: true)
        return (
            try Data(contentsOf: root.appendingPathComponent("Baselines.json")),
            try Data(contentsOf: root.appendingPathComponent("BaselineProvenance.json"))
        )
    }
}

private struct ProvenanceFixture: Codable {
    var schemaVersion: Int
    let origin: Origin
    var snapshots: [BaselineProvenance]

    struct Origin: Codable {
        let kind: String
        let catalogSHA256: String
    }
}
