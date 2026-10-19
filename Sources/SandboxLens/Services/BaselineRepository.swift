import Foundation

enum BaselineRepository {
    static func loadBundledCatalog() throws -> BaselineCatalog {
        let catalogData = try bundledData(resourceName: "Baselines")
        let provenanceData = try bundledData(resourceName: "BaselineProvenance")
        return try loadCatalog(catalogData: catalogData, provenanceData: provenanceData)
    }

    /// Verifies the exact resource pair before attaching qualified source declarations to releases.
    static func loadCatalog(catalogData: Data, provenanceData: Data) throws -> BaselineCatalog {
        let catalogLimit = 64 * 1_024 * 1_024
        let provenanceLimit = 2 * 1_024 * 1_024
        guard !catalogData.isEmpty, catalogData.count <= catalogLimit else {
            throw BaselineRepositoryError.invalidResourceSize(resourceName: "Baselines", limit: catalogLimit)
        }
        guard !provenanceData.isEmpty, provenanceData.count <= provenanceLimit else {
            throw BaselineRepositoryError.invalidResourceSize(resourceName: "BaselineProvenance", limit: provenanceLimit)
        }
        let catalog = try decode(BaselineCatalog.self, data: catalogData, resourceName: "Baselines").validated()
        let provenance = try decode(
            BaselineProvenanceDocument.self,
            data: provenanceData,
            resourceName: "BaselineProvenance"
        ).validated(catalog: catalog, catalogData: catalogData)
        let annotations = Dictionary(uniqueKeysWithValues: provenance.snapshots.map { ($0.id, $0) })
        let releases = try catalog.releases.map { release in
            guard let annotation = annotations[release.id] else {
                throw BaselineProvenanceError.incompleteAnnotations
            }
            return release.withProvenance(annotation)
        }
        return BaselineCatalog(schemaVersion: catalog.schemaVersion, generatedAt: catalog.generatedAt, releases: releases)
    }

    private static func bundledData(resourceName: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw BaselineRepositoryError.resourceMissing(resourceName: resourceName)
        }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, data: Data, resourceName: String) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw BaselineRepositoryError.decodeFailed(
                resourceName: resourceName,
                underlyingDescription: error.localizedDescription
            )
        }
    }
}

enum BaselineRepositoryError: LocalizedError {
    case resourceMissing(resourceName: String)
    case invalidResourceSize(resourceName: String, limit: Int)
    case decodeFailed(resourceName: String, underlyingDescription: String)

    var errorDescription: String? {
        switch self {
        case .resourceMissing(let resourceName):
            "The \(resourceName).json resource is missing from the app bundle. Rebuild with the catalog and its paired provenance."
        case .invalidResourceSize(let resourceName, let limit):
            "The \(resourceName).json resource must contain between 1 and \(limit) bytes. Restore its validated source resource."
        case .decodeFailed(let resourceName, let underlyingDescription):
            "The \(resourceName).json baseline resource could not be decoded: \(underlyingDescription)"
        }
    }
}
