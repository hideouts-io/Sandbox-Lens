import Foundation

enum BaselineSourceKind: String, Codable, Hashable, Sendable {
    case communitySnapshot = "community-snapshot"
    case localCapture = "local-capture"
}

enum BaselineAttribution: String, Codable, Hashable, Sendable {
    case declaredUnverified = "declared-unverified"
    case conflicting
}

enum BaselineCoverage: String, Codable, Hashable, Sendable {
    case recordedPathsOnly = "recorded-paths-only"
}

struct BaselineProvenanceEvidence: Codable, Hashable, Sendable {
    let url: String
    let sha256: String
    let productVersion: String
    let buildVersion: String
}

struct BaselineProvenance: Codable, Hashable, Sendable {
    let id: String
    let sourceKind: BaselineSourceKind
    let attribution: BaselineAttribution
    let architecture: String?
    let collectedAt: String?
    let roots: [String]
    let coverage: BaselineCoverage
    let evidence: [BaselineProvenanceEvidence]
    let limitations: [String]

    private enum CodingKeys: String, CodingKey {
        case id, sourceKind, attribution, architecture, collectedAt, roots, coverage, evidence, limitations
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sourceKind = try container.decode(BaselineSourceKind.self, forKey: .sourceKind)
        attribution = try container.decode(BaselineAttribution.self, forKey: .attribution)
        architecture = try container.decode(String?.self, forKey: .architecture)
        collectedAt = try container.decode(String?.self, forKey: .collectedAt)
        roots = try container.decode([String].self, forKey: .roots)
        coverage = try container.decode(BaselineCoverage.self, forKey: .coverage)
        evidence = try container.decode([BaselineProvenanceEvidence].self, forKey: .evidence)
        limitations = try container.decode([String].self, forKey: .limitations)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceKind, forKey: .sourceKind)
        try container.encode(attribution, forKey: .attribution)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(collectedAt, forKey: .collectedAt)
        try container.encode(roots, forKey: .roots)
        try container.encode(coverage, forKey: .coverage)
        try container.encode(evidence, forKey: .evidence)
        try container.encode(limitations, forKey: .limitations)
    }

    func validated(release: BaselineRelease) throws -> BaselineProvenance {
        guard id.range(of: "^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$", options: .regularExpression) != nil else {
            throw BaselineProvenanceError.invalidSnapshotIdentifier
        }
        guard architecture.map({
            $0.range(of: "^[A-Za-z0-9_.+-]{1,128}$", options: .regularExpression) != nil
        }) ?? true else {
            throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "architecture")
        }
        guard collectedAt.map(validCollectionTimestamp) ?? true else {
            throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "collectedAt")
        }
        let allowedRoots: Set<String> = ["usr/share/sandbox", "System/Library/Sandbox/Profiles"]
        guard !roots.isEmpty, roots.count <= 2, Set(roots).count == roots.count,
              Set(roots).isSubset(of: allowedRoots) else {
            throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "roots")
        }
        let observedRoots = Set(release.profiles.compactMap { profile in
            allowedRoots.first { profile.relativePath.hasPrefix($0 + "/") }
        })
        guard observedRoots == Set(roots) else {
            throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "recorded root coverage")
        }
        guard !limitations.isEmpty, limitations.count <= 32,
              Set(limitations).count == limitations.count,
              limitations.allSatisfy({ !$0.isEmpty && $0.count <= 4_096 }) else {
            throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "limitations")
        }
        guard evidence.count <= 32 else {
            throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "evidence")
        }
        for record in evidence {
            guard record.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
                  [record.url, record.productVersion, record.buildVersion].allSatisfy({
                      !$0.isEmpty && $0.count <= 4_096
                  }),
                  let url = URL(string: record.url), url.scheme == "https", url.host != nil,
                  url.user == nil, url.password == nil else {
                throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "evidence")
            }
        }
        let versions = Set(evidence.map {
            SystemIdentity(productVersion: $0.productVersion, buildVersion: $0.buildVersion)
        } + [SystemIdentity(productVersion: release.productVersion, buildVersion: release.buildVersion)])
        guard versions.count <= 1 || attribution == .conflicting else {
            throw BaselineProvenanceError.invalidAnnotation(snapshotID: id, field: "unqualified conflicting evidence")
        }
        return self
    }

    private func validCollectionTimestamp(_ value: String) -> Bool {
        guard value.count <= 64,
              value.range(
                  of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$",
                  options: .regularExpression
              ) != nil else {
            return false
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = value.contains(".") ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: value) != nil
    }
}

/// Decodes only fields consumed by the app; the complete schema-2 source remains bundled unchanged.
struct BaselineProvenanceDocument: Decodable, Sendable {
    let schemaVersion: Int
    let origin: BaselineProvenanceOrigin
    let snapshots: [BaselineProvenance]

    func validated(catalog: BaselineCatalog, catalogData: Data) throws -> BaselineProvenanceDocument {
        guard schemaVersion == 2 else {
            throw BaselineProvenanceError.unsupportedSchema(schemaVersion)
        }
        guard origin.catalogSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw BaselineProvenanceError.invalidCatalogHash
        }
        guard origin.catalogSHA256 == ProfileScanner.sha256(data: catalogData) else {
            throw BaselineProvenanceError.catalogHashMismatch
        }
        guard !snapshots.isEmpty, snapshots.count <= 1_000 else {
            throw BaselineProvenanceError.invalidAnnotationCount
        }
        let identifiers = snapshots.map(\.id)
        guard Set(identifiers).count == identifiers.count else {
            throw BaselineProvenanceError.duplicateSnapshotIdentifier
        }
        guard Set(identifiers) == Set(catalog.releases.map(\.id)) else {
            throw BaselineProvenanceError.incompleteAnnotations
        }
        let releases = Dictionary(uniqueKeysWithValues: catalog.releases.map { ($0.id, $0) })
        for snapshot in snapshots {
            guard let release = releases[snapshot.id] else {
                throw BaselineProvenanceError.incompleteAnnotations
            }
            _ = try snapshot.validated(release: release)
        }
        return self
    }
}

struct BaselineProvenanceOrigin: Decodable, Sendable {
    let kind: Kind
    let catalogSHA256: String

    enum Kind: String, Decodable, Sendable {
        case generatedCatalog = "generated-catalog"
        case repositoryResource = "repository-resource"
    }
}

enum BaselineProvenanceError: LocalizedError {
    case unsupportedSchema(Int)
    case invalidCatalogHash
    case catalogHashMismatch
    case invalidAnnotationCount
    case invalidSnapshotIdentifier
    case duplicateSnapshotIdentifier
    case incompleteAnnotations
    case invalidAnnotation(snapshotID: String, field: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "The bundled baseline provenance uses unsupported schema version \(version). Rebuild with schema 2 metadata."
        case .invalidCatalogHash:
            "The baseline provenance contains an invalid catalog SHA-256. Rebuild with the original paired resources."
        case .catalogHashMismatch:
            "The baseline catalog does not match its provenance SHA-256. Rebuild with the original paired resources."
        case .invalidAnnotationCount:
            "The baseline provenance must contain between 1 and 1,000 snapshot annotations."
        case .invalidSnapshotIdentifier:
            "A baseline provenance snapshot identifier is invalid. Use the identifier from the paired catalog."
        case .duplicateSnapshotIdentifier:
            "The baseline provenance contains duplicate snapshot identifiers. Keep one annotation per catalog release."
        case .incompleteAnnotations:
            "The baseline provenance does not cover exactly the catalog releases. Rebuild with the original paired resources."
        case .invalidAnnotation(let snapshotID, let field):
            "Baseline provenance for \(snapshotID) has invalid \(field). Restore its validated source annotation."
        }
    }
}
