import Foundation

enum ProfileSourceReader {
    /// Reads a scanned profile again before displaying its original text.
    static func read(profile: ScannedProfile, scan: ScanResult) throws -> String {
        try Task.checkCancellation()
        guard scan.profiles.contains(profile) else {
            throw ProfileSourceReaderError.profileNotInScan(path: profile.fileURL.path)
        }
        let root = try sourceRoot(profile: profile, roots: scan.roots)
        let accessed = root.url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                root.url.stopAccessingSecurityScopedResource()
            }
        }

        let read: (profile: ScannedProfile, data: Data)
        do {
            read = try ProfileScanner().readProfile(fileURL: profile.fileURL, root: root)
        } catch let error as ProfileScannerError {
            if case .readFailed = error {
                throw ProfileSourceReaderError.sourceUnavailable(path: profile.fileURL.path, underlying: error)
            }
            if case .pathResolutionFailed = error {
                throw ProfileSourceReaderError.sourceUnavailable(path: profile.fileURL.path, underlying: error)
            }
            throw error
        }
        guard read.profile == profile else {
            throw ProfileSourceReaderError.sourceChanged(path: profile.fileURL.path)
        }
        try Task.checkCancellation()
        guard let source = String(data: read.data, encoding: .utf8) else {
            throw ProfileSourceReaderError.invalidUTF8(path: profile.fileURL.path)
        }
        return source
    }

    private static func sourceRoot(profile: ScannedProfile, roots: [ScanRoot]) throws -> ScanRoot {
        let matches = roots.filter { root in
            profile.relativePath.hasPrefix(root.baselinePrefix + "/")
        }
        guard matches.count == 1, let root = matches.first else {
            throw ProfileSourceReaderError.sourceRootUnavailable(path: profile.fileURL.path)
        }
        return root
    }
}

enum ProfileSourceReaderError: LocalizedError {
    case profileNotInScan(path: String)
    case sourceRootUnavailable(path: String)
    case sourceUnavailable(path: String, underlying: ProfileScannerError)
    case sourceChanged(path: String)
    case invalidUTF8(path: String)

    var errorDescription: String? {
        switch self {
        case .profileNotInScan(let path):
            "The selected profile was not part of this scan: \(path). Select a scanned profile."
        case .sourceRootUnavailable(let path):
            "The scan folder for \(path) could not be identified. Scan the folder again."
        case .sourceUnavailable(let path, let underlying):
            "The scanned profile at \(path) is no longer available for text viewing: \(underlying.localizedDescription) Scan the folder again."
        case .sourceChanged(let path):
            "The profile at \(path) changed after the scan. Scan the folder again before viewing its text."
        case .invalidUTF8(let path):
            "The profile at \(path) is not valid UTF-8 text. Scan the folder again."
        }
    }
}
