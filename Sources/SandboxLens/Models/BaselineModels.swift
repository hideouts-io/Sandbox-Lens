import Foundation

struct BaselineCatalog: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let releases: [BaselineRelease]

    func validated() throws -> BaselineCatalog {
        guard schemaVersion == 1 else {
            throw BaselineCatalogError.unsupportedSchema(schemaVersion)
        }
        guard !releases.isEmpty else {
            throw BaselineCatalogError.emptyCatalog
        }

        let identifiers = releases.map(\.id)
        guard Set(identifiers).count == identifiers.count else {
            throw BaselineCatalogError.duplicateReleaseIdentifier
        }

        for release in releases {
            guard release.profileCount == release.profiles.count else {
                throw BaselineCatalogError.incorrectProfileCount(
                    releaseID: release.id,
                    declared: release.profileCount,
                    actual: release.profiles.count
                )
            }
            for profile in release.profiles {
                guard profile.sha256.count == 64 else {
                    throw BaselineCatalogError.invalidHash(
                        releaseID: release.id,
                        path: profile.relativePath
                    )
                }
                guard profile.isSymbolicLink == (profile.symbolicLinkTarget != nil) else {
                    throw BaselineCatalogError.invalidSymbolicLinkMetadata(
                        releaseID: release.id,
                        path: profile.relativePath
                    )
                }
            }
        }
        return self
    }
}

struct BaselineRelease: Codable, Identifiable, Hashable, Sendable {
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
    let profileCount: Int
    let profiles: [BaselineProfile]

    var isBeta: Bool {
        releaseChannel == "beta"
    }

    var majorVersion: Int? {
        Int(productVersion.split(separator: ".").first ?? "")
    }
}

struct BaselineProfile: Codable, Identifiable, Hashable, Sendable {
    let relativePath: String
    let fileName: String
    let sha256: String
    let sizeBytes: Int
    let isSymbolicLink: Bool
    let symbolicLinkTarget: String?
    let analysis: ProfileAnalysis

    var id: String {
        relativePath
    }
}

struct ProfileAnalysis: Codable, Hashable, Sendable {
    let allowCount: Int
    let denyCount: Int
    let imports: [String]
    let hasDenyDefault: Bool
    let hasAllowDefault: Bool
    let hasGlobalFileRead: Bool
    let hasGlobalFileWrite: Bool
    let hasGlobalFileReadWrite: Bool
    let hasGlobalProcessExec: Bool
    let hasGlobalNetwork: Bool
    let hasNoSandboxExecution: Bool

    var reviewSignals: [ReviewSignal] {
        var signals: [ReviewSignal] = []
        if hasAllowDefault {
            signals.append(.allowDefault)
        }
        if hasNoSandboxExecution {
            signals.append(.noSandboxExecution)
        }
        if hasGlobalFileReadWrite {
            signals.append(.globalFileReadWrite)
        } else {
            if hasGlobalFileRead {
                signals.append(.globalFileRead)
            }
            if hasGlobalFileWrite {
                signals.append(.globalFileWrite)
            }
        }
        if hasGlobalProcessExec {
            signals.append(.globalProcessExecution)
        }
        if hasGlobalNetwork {
            signals.append(.globalNetwork)
        }
        if !hasDenyDefault && !hasAllowDefault {
            signals.append(.supportFragment)
        }
        return signals
    }
}

enum ReviewSignal: String, Codable, CaseIterable, Identifiable, Sendable {
    case allowDefault
    case noSandboxExecution
    case globalFileReadWrite
    case globalFileRead
    case globalFileWrite
    case globalProcessExecution
    case globalNetwork
    case supportFragment

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .allowDefault: "Permissive starting policy"
        case .noSandboxExecution: "Unsandboxed child execution"
        case .globalFileReadWrite: "Broad file reading and writing"
        case .globalFileRead: "Broad file reading"
        case .globalFileWrite: "Broad file writing"
        case .globalProcessExecution: "Broad program execution"
        case .globalNetwork: "Broad network access"
        case .supportFragment: "Imported support fragment"
        }
    }

    var plainExplanation: String {
        switch self {
        case .allowDefault:
            "The profile starts by permitting operations unless a later rule denies them. This deserves careful review."
        case .noSandboxExecution:
            "At least one allowed child process may launch without inheriting this sandbox. Apple uses this selectively in some diagnostic profiles."
        case .globalFileReadWrite:
            "The profile contains an unfiltered rule that permits both reading and writing files."
        case .globalFileRead:
            "The profile contains an unfiltered rule that permits reading files."
        case .globalFileWrite:
            "The profile contains an unfiltered rule that permits writing files."
        case .globalProcessExecution:
            "The profile contains an unfiltered rule permitting programs to be launched."
        case .globalNetwork:
            "The profile contains an unfiltered rule permitting network operations."
        case .supportFragment:
            "This file does not set a default policy. It is probably intended to be imported into another profile rather than loaded alone."
        }
    }
}

enum BaselineCatalogError: LocalizedError {
    case unsupportedSchema(Int)
    case emptyCatalog
    case duplicateReleaseIdentifier
    case incorrectProfileCount(releaseID: String, declared: Int, actual: Int)
    case invalidHash(releaseID: String, path: String)
    case invalidSymbolicLinkMetadata(releaseID: String, path: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "The bundled baseline catalog uses unsupported schema version \(version)."
        case .emptyCatalog:
            "The bundled baseline catalog contains no releases."
        case .duplicateReleaseIdentifier:
            "The bundled baseline catalog contains duplicate release identifiers."
        case .incorrectProfileCount(let releaseID, let declared, let actual):
            "Baseline \(releaseID) declares \(declared) profiles but contains \(actual)."
        case .invalidHash(let releaseID, let path):
            "Baseline \(releaseID) contains an invalid SHA-256 value for \(path)."
        case .invalidSymbolicLinkMetadata(let releaseID, let path):
            "Baseline \(releaseID) contains inconsistent symbolic-link metadata for \(path)."
        }
    }
}
