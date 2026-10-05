import Foundation

struct RuntimeSpecimenAppIdentity: Codable, Sendable {
    let bundleIdentifier: String?
    let version: String?
    let build: String?

    static func read(bundle: Bundle) throws -> RuntimeSpecimenAppIdentity {
        RuntimeSpecimenAppIdentity(
            bundleIdentifier: try metadataString(bundle: bundle, key: "CFBundleIdentifier"),
            version: try metadataString(bundle: bundle, key: "CFBundleShortVersionString"),
            build: try metadataString(bundle: bundle, key: "CFBundleVersion")
        )
    }

    private static func metadataString(bundle: Bundle, key: String) throws -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) else {
            return nil
        }
        guard let string = value as? String, !string.isEmpty else {
            throw RuntimeSpecimenError.invalidAppMetadata(key: key, bundlePath: bundle.bundlePath)
        }
        return string
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, version, build
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(version, forKey: .version)
        try container.encode(build, forKey: .build)
    }
}

struct RuntimeSpecimenSource: Codable, Sendable {
    let relativePath: String
    let fileName: String
    let fileURL: URL
    let scanRootURL: URL
    let sha256: String
    let sizeBytes: Int
    let isSymbolicLink: Bool
    let symbolicLinkTarget: String?
    let originatingSystem: SystemIdentity?

    private enum CodingKeys: String, CodingKey {
        case relativePath, fileName, fileURL, scanRootURL, sha256, sizeBytes
        case isSymbolicLink, symbolicLinkTarget, originatingSystem
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(fileURL, forKey: .fileURL)
        try container.encode(scanRootURL, forKey: .scanRootURL)
        try container.encode(sha256, forKey: .sha256)
        try container.encode(sizeBytes, forKey: .sizeBytes)
        try container.encode(isSymbolicLink, forKey: .isSymbolicLink)
        try container.encode(symbolicLinkTarget, forKey: .symbolicLinkTarget)
        try container.encode(originatingSystem, forKey: .originatingSystem)
    }
}

struct RuntimeSpecimenBaseline: Codable, Sendable {
    let id: String
    let displayName: String
    let productVersion: String
    let buildVersion: String
    let releaseChannel: String
    let sourceName: String
    let sourceURL: String
    let sourceCommit: String
    let confidence: String
    let notes: String

    init(release: BaselineRelease) {
        id = release.id
        displayName = release.displayName
        productVersion = release.productVersion
        buildVersion = release.buildVersion
        releaseChannel = release.releaseChannel
        sourceName = release.sourceName
        sourceURL = release.sourceURL
        sourceCommit = release.sourceCommit
        confidence = release.confidence
        notes = release.notes
    }
}

struct RuntimeSpecimenScan: Codable, Sendable {
    let startedAt: Date
    let completedAt: Date
}

struct RuntimeSpecimenComparison: Codable, Sendable {
    let status: ComparisonStatus
    let method: ComparisonMethod
    let changes: [String]
    let matchedBaseline: BaselineProfile?

    private enum CodingKeys: String, CodingKey {
        case status, method, changes, matchedBaseline
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(method, forKey: .method)
        try container.encode(changes, forKey: .changes)
        try container.encode(matchedBaseline, forKey: .matchedBaseline)
    }
}

enum RuntimeSpecimenObservation: String, Codable, Sendable {
    case notPerformed = "not performed"
}

struct RuntimeSpecimenPolicyWitnessReference: Codable, Sendable {
    let repositoryURL: String
    let revision: String
    let requestSchemaVersion: Int
    let responseSchemaVersion: Int
    let controllerEnvelopeSchemaVersion: Int
}

/// Static export metadata, independent of PolicyWitness's executable request contract.
struct RuntimeSpecimenManifest: Codable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let app: RuntimeSpecimenAppIdentity
    let scanningHost: SystemIdentity
    let scan: RuntimeSpecimenScan
    let source: RuntimeSpecimenSource
    let comparison: RuntimeSpecimenComparison
    let selectedBaseline: RuntimeSpecimenBaseline?
    let staticAnalysis: ProfileAnalysis
    let runtimeObservation: RuntimeSpecimenObservation
    let policyWitnessReference: RuntimeSpecimenPolicyWitnessReference

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, app, scanningHost, scan, source, comparison
        case selectedBaseline, staticAnalysis, runtimeObservation, policyWitnessReference
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(app, forKey: .app)
        try container.encode(scanningHost, forKey: .scanningHost)
        try container.encode(scan, forKey: .scan)
        try container.encode(source, forKey: .source)
        try container.encode(comparison, forKey: .comparison)
        try container.encode(selectedBaseline, forKey: .selectedBaseline)
        try container.encode(staticAnalysis, forKey: .staticAnalysis)
        try container.encode(runtimeObservation, forKey: .runtimeObservation)
        try container.encode(policyWitnessReference, forKey: .policyWitnessReference)
    }
}
