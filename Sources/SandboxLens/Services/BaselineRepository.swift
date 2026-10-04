import Foundation

enum BaselineRepository {
    static func loadBundledCatalog() throws -> BaselineCatalog {
        guard let url = Bundle.module.url(forResource: "Baselines", withExtension: "json") else {
            throw BaselineRepositoryError.resourceMissing
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        do {
            let catalog = try JSONDecoder().decode(BaselineCatalog.self, from: data)
            return try catalog.validated()
        } catch let error as BaselineCatalogError {
            throw error
        } catch {
            throw BaselineRepositoryError.decodeFailed(
                path: url.path,
                underlyingDescription: error.localizedDescription
            )
        }
    }
}

enum BaselineRepositoryError: LocalizedError {
    case resourceMissing
    case decodeFailed(path: String, underlyingDescription: String)

    var errorDescription: String? {
        switch self {
        case .resourceMissing:
            "The Baselines.json resource is missing from the app bundle. Rebuild the app after generating the baseline manifest."
        case .decodeFailed(let path, let underlyingDescription):
            "The baseline catalog at \(path) could not be decoded: \(underlyingDescription)"
        }
    }
}
