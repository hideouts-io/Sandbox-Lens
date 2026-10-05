import Foundation

struct SystemIdentity: Codable, Hashable, Sendable {
    let productVersion: String
    let buildVersion: String

    var displayName: String {
        "macOS \(productVersion) (\(buildVersion))"
    }
}

struct ScanRoot: Hashable, Sendable {
    let url: URL
    let baselinePrefix: String
    let displayName: String
}

struct ScannedProfile: Identifiable, Hashable, Sendable {
    let relativePath: String
    let fileName: String
    let fileURL: URL
    let sha256: String
    let sizeBytes: Int
    let isSymbolicLink: Bool
    let symbolicLinkTarget: String?
    let analysis: ProfileAnalysis

    var id: String {
        relativePath
    }
}

enum ComparisonStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case match
    case changed
    case missing
    case unexpected
    case unverified

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .match: "Matches baseline"
        case .changed: "Different"
        case .missing: "Expected but missing"
        case .unexpected: "Not in baseline"
        case .unverified: "Not verified"
        }
    }

    var shortTitle: String {
        switch self {
        case .match: "Match"
        case .changed: "Different"
        case .missing: "Missing"
        case .unexpected: "Additional"
        case .unverified: "Unverified"
        }
    }

    var plainExplanation: String {
        switch self {
        case .match:
            "The file has the same SHA-256 fingerprint as the selected baseline."
        case .changed:
            "A profile with this name is expected, but its contents differ. An OS update can cause this; it is a review finding, not proof of malware."
        case .missing:
            "The selected baseline contains this profile, but the scan did not find it. The baseline may not exactly match this Mac."
        case .unexpected:
            "The scan found this profile, but it is not listed in the selected baseline. It may come from another OS release or installed software."
        case .unverified:
            "There is no unambiguous baseline entry for this file, so the app reports its properties without declaring it normal or abnormal."
        }
    }
}

enum ComparisonMethod: String, Codable, Sendable {
    case exactPath
    case uniqueFileName
    case none

    var explanation: String {
        switch self {
        case .exactPath: "Compared using the complete installed path."
        case .uniqueFileName: "Compared by filename because the scanned folder is not a standard system location."
        case .none: "No unique baseline counterpart was available."
        }
    }
}

struct ProfileComparison: Identifiable, Hashable, Sendable {
    let id: String
    let relativePath: String
    let fileName: String
    let status: ComparisonStatus
    let method: ComparisonMethod
    let scanned: ScannedProfile?
    let baseline: BaselineProfile?
    let changes: [String]

    var analysis: ProfileAnalysis? {
        scanned?.analysis ?? baseline?.analysis
    }
}

struct ScanResult: Sendable {
    let startedAt: Date
    let completedAt: Date
    let roots: [ScanRoot]
    let profiles: [ScannedProfile]
}

enum SidebarDestination: String, CaseIterable, Identifiable {
    case overview
    case allProfiles
    case changed
    case missing
    case unexpected
    case baselines
    case learn

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .allProfiles: "All profiles"
        case .changed: "Different"
        case .missing: "Missing"
        case .unexpected: "Additional"
        case .baselines: "Baseline library"
        case .learn: "What this means"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .allProfiles: "doc.text.magnifyingglass"
        case .changed: "exclamationmark.triangle"
        case .missing: "questionmark.folder"
        case .unexpected: "plus.rectangle.on.folder"
        case .baselines: "books.vertical"
        case .learn: "lightbulb"
        }
    }
}
