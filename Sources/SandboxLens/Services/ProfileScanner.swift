import CryptoKit
import Darwin
import Foundation

struct ProfileScanner: Sendable {
    static let maximumProfileSizeBytes = 16 * 1_024 * 1_024

    func scan(roots: [ScanRoot]) async throws -> ScanResult {
        try await Task.detached(priority: .userInitiated) {
            let startedAt = Date()
            var profiles: [ScannedProfile] = []
            for root in roots {
                profiles.append(contentsOf: try scan(root: root))
            }
            return ScanResult(
                startedAt: startedAt,
                completedAt: Date(),
                roots: roots,
                profiles: profiles.sorted { $0.relativePath < $1.relativePath }
            )
        }.value
    }

    static func systemRoots() -> [ScanRoot] {
        [
            ScanRoot(
                url: URL(fileURLWithPath: "/usr/share/sandbox", isDirectory: true),
                baselinePrefix: "usr/share/sandbox",
                displayName: "/usr/share/sandbox"
            ),
            ScanRoot(
                url: URL(fileURLWithPath: "/System/Library/Sandbox/Profiles", isDirectory: true),
                baselinePrefix: "System/Library/Sandbox/Profiles",
                displayName: "/System/Library/Sandbox/Profiles"
            )
        ]
    }

    static func importedRoot(url: URL) -> ScanRoot {
        ScanRoot(
            url: url,
            baselinePrefix: "Imported",
            displayName: url.path
        )
    }

    static func validateImportedFolderURL(url: URL) throws {
        let selectedPath = url.standardizedFileURL.path
        let overlyBroadPaths: Set<String> = [
            "/",
            "/System",
            "/System/Library",
            "/Library",
            "/usr",
            "/usr/share"
        ]
        guard !overlyBroadPaths.contains(selectedPath) else {
            throw ProfileScannerError.folderTooBroad(path: selectedPath)
        }
    }

    private func scan(root: ScanRoot) throws -> [ScannedProfile] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ProfileScannerError.rootUnavailable(path: root.url.path)
        }

        let accessed = root.url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                root.url.stopAccessingSecurityScopedResource()
            }
        }

        let profileURLs = try enumerateProfileURLs(directoryURL: root.url)
        guard !profileURLs.isEmpty else {
            throw ProfileScannerError.noProfilesFound(path: root.url.path)
        }

        return try profileURLs.map { profileURL in
            try readProfile(fileURL: profileURL, root: root).profile
        }
    }

    /// Reads source bytes and metadata using the same boundaries as a scan.
    func readProfile(fileURL: URL, root: ScanRoot) throws -> (profile: ScannedProfile, data: Data) {
        let profileURL = URL(fileURLWithPath: fileURL.path)
        try validateResolvedPath(fileURL: profileURL, rootURL: root.url)
        let data = try readProfileData(fileURL: profileURL, rootURL: root.url)
        let resourceValues = try profileURL.resourceValues(
            forKeys: [.isSymbolicLinkKey]
        )

        let relativeComponent = try relativePath(fileURL: profileURL, rootURL: root.url)
        let baselinePath = root.baselinePrefix + "/" + relativeComponent
        let digest = Self.sha256(data: data)
        let isSymbolicLink = resourceValues.isSymbolicLink == true
        let symbolicLinkTarget: String?
        if isSymbolicLink {
            do {
                symbolicLinkTarget = try FileManager.default.destinationOfSymbolicLink(
                    atPath: profileURL.path
                )
            } catch {
                throw ProfileScannerError.symbolicLinkReadFailed(
                    path: profileURL.path,
                    underlyingDescription: error.localizedDescription
                )
            }
        } else {
            symbolicLinkTarget = nil
        }
        let analysis = try ProfileTextAnalyzer.analyze(
            data: data,
            sourcePath: profileURL.path
        )
        let profile = ScannedProfile(
            relativePath: baselinePath,
            fileName: profileURL.lastPathComponent,
            fileURL: profileURL,
            sha256: digest,
            sizeBytes: data.count,
            isSymbolicLink: isSymbolicLink,
            symbolicLinkTarget: symbolicLinkTarget,
            analysis: analysis
        )
        try validateResolvedPath(fileURL: profileURL, rootURL: root.url)
        return (profile, data)
    }

    static func sha256(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func readProfileData(fileURL: URL, rootURL: URL) throws -> Data {
        let rootPath = try canonicalExistingPath(url: rootURL)
        let descriptor = fileURL.path.withCString { open($0, O_RDONLY | O_NONBLOCK | O_CLOEXEC) }
        guard descriptor >= 0 else {
            throw nativeReadError(path: fileURL.path, operation: "open", errnoValue: errno)
        }

        let data: Data
        do {
            data = try readProfileDescriptor(descriptor: descriptor, path: fileURL.path, rootPath: rootPath)
        } catch {
            let primaryError = error
            guard close(descriptor) == 0 else {
                let closeError = nativeReadError(path: fileURL.path, operation: "close", errnoValue: errno)
                throw ProfileScannerError.readFailed(
                    path: fileURL.path,
                    underlyingDescription: "\(primaryError.localizedDescription) Descriptor cleanup also failed: \(closeError.localizedDescription)"
                )
            }
            throw primaryError
        }
        guard close(descriptor) == 0 else {
            throw nativeReadError(path: fileURL.path, operation: "close", errnoValue: errno)
        }
        return data
    }

    private func readProfileDescriptor(descriptor: Int32, path: String, rootPath: String) throws -> Data {
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            throw nativeReadError(path: path, operation: "fstat", errnoValue: errno)
        }
        guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw ProfileScannerError.profileNotRegularFile(path: path)
        }
        guard metadata.st_size <= off_t(Self.maximumProfileSizeBytes) else {
            throw ProfileScannerError.profileTooLarge(
                path: path,
                sizeBytes: Int(metadata.st_size),
                maximumBytes: Self.maximumProfileSizeBytes
            )
        }
        try validateDescriptorPath(descriptor: descriptor, path: path, rootPath: rootPath)

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while data.count <= Self.maximumProfileSizeBytes {
            let capacity = min(buffer.count, Self.maximumProfileSizeBytes + 1 - data.count)
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, capacity)
            }
            guard count >= 0 else {
                throw nativeReadError(path: path, operation: "read", errnoValue: errno)
            }
            if count == 0 {
                try validateDescriptorPath(descriptor: descriptor, path: path, rootPath: rootPath)
                return data
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        throw ProfileScannerError.profileTooLarge(
            path: path,
            sizeBytes: data.count,
            maximumBytes: Self.maximumProfileSizeBytes
        )
    }

    private func validateDescriptorPath(descriptor: Int32, path: String, rootPath: String) throws {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let result = fcntl(descriptor, F_GETPATH, &buffer)
        guard result == 0 else {
            throw nativeReadError(path: path, operation: "fcntl(F_GETPATH)", errnoValue: errno)
        }
        let descriptorPath = decodePathBuffer(buffer: buffer)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard descriptorPath.hasPrefix(prefix) else {
            throw ProfileScannerError.pathEscapedRoot(file: descriptorPath, root: rootPath)
        }
    }

    private func nativeReadError(path: String, operation: String, errnoValue: Int32) -> ProfileScannerError {
        ProfileScannerError.readFailed(
            path: path,
            underlyingDescription: "\(operation) failed: errno=\(errnoValue) (\(String(cString: strerror(errnoValue))))."
        )
    }

    private func enumerateProfileURLs(directoryURL: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw ProfileScannerError.enumerationFailed(
                path: directoryURL.path,
                underlyingDescription: error.localizedDescription
            )
        }

        var results: [URL] = []
        for entry in entries {
            let values = try entry.resourceValues(forKeys: keys)
            if values.isSymbolicLink == true {
                if entry.pathExtension.lowercased() == "sb" {
                    results.append(entry)
                }
            } else if values.isDirectory == true {
                results.append(contentsOf: try enumerateProfileURLs(directoryURL: entry))
            } else if entry.pathExtension.lowercased() == "sb" {
                results.append(entry)
            }
        }
        return results.sorted { $0.path < $1.path }
    }

    private func relativePath(fileURL: URL, rootURL: URL) throws -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            throw ProfileScannerError.pathEscapedRoot(file: filePath, root: rootPath)
        }
        return String(filePath.dropFirst(prefix.count))
    }

    private func validateResolvedPath(fileURL: URL, rootURL: URL) throws {
        let resolvedRootPath = try canonicalExistingPath(url: rootURL)
        let resolvedFilePath = try canonicalPathAllowingMissingLeaf(url: fileURL)
        let prefix = resolvedRootPath.hasSuffix("/")
            ? resolvedRootPath
            : resolvedRootPath + "/"
        guard resolvedFilePath.hasPrefix(prefix) else {
            throw ProfileScannerError.pathEscapedRoot(
                file: resolvedFilePath,
                root: resolvedRootPath
            )
        }
    }

    private func canonicalExistingPath(url: URL) throws -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let result = url.path.withCString { pointer in
            realpath(pointer, &buffer)
        }
        guard result != nil else {
            throw ProfileScannerError.pathResolutionFailed(
                path: url.path,
                underlyingDescription: String(cString: strerror(errno))
            )
        }
        return decodePathBuffer(buffer: buffer)
    }

    private func canonicalPathAllowingMissingLeaf(url: URL) throws -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let result = url.path.withCString { pointer in
            realpath(pointer, &buffer)
        }
        if result != nil {
            return decodePathBuffer(buffer: buffer)
        }

        let errorCode = errno
        guard errorCode == ENOENT else {
            throw ProfileScannerError.pathResolutionFailed(
                path: url.path,
                underlyingDescription: String(cString: strerror(errorCode))
            )
        }
        let parentPath = try canonicalExistingPath(url: url.deletingLastPathComponent())
        return URL(fileURLWithPath: parentPath, isDirectory: true)
            .appendingPathComponent(url.lastPathComponent)
            .standardizedFileURL.path
    }

    private func decodePathBuffer(buffer: [CChar]) -> String {
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

enum ProfileScannerError: LocalizedError {
    case rootUnavailable(path: String)
    case folderTooBroad(path: String)
    case noProfilesFound(path: String)
    case profileNotRegularFile(path: String)
    case profileTooLarge(path: String, sizeBytes: Int, maximumBytes: Int)
    case enumerationFailed(path: String, underlyingDescription: String)
    case readFailed(path: String, underlyingDescription: String)
    case symbolicLinkReadFailed(path: String, underlyingDescription: String)
    case pathEscapedRoot(file: String, root: String)
    case pathResolutionFailed(path: String, underlyingDescription: String)

    var errorDescription: String? {
        switch self {
        case .rootUnavailable(let path):
            "The scan folder is unavailable or is not a directory: \(path)"
        case .folderTooBroad(let path):
            "The selected folder is too broad to scan safely: \(path). Choose the folder that directly contains the .sb files. For Apple system profiles, use Scan This Mac instead."
        case .noProfilesFound(let path):
            "No .sb files were found inside \(path). Choose a folder that contains sandbox profiles, such as a copied folder named sandbox."
        case .profileNotRegularFile(let path):
            "The sandbox profile \(path) is not a regular file. Select a regular .sb file or a symbolic link to one within the scan root."
        case .profileTooLarge(let path, let sizeBytes, let maximumBytes):
            "The sandbox profile \(path) is \(sizeBytes) bytes, which exceeds the \(maximumBytes)-byte safety limit."
        case .enumerationFailed(let path, let underlyingDescription):
            "The folder \(path) is protected and could not be read completely: \(underlyingDescription) Choose the folder that directly contains the .sb files. For Apple system profiles, use Scan This Mac."
        case .readFailed(let path, let underlyingDescription):
            "The sandbox profile \(path) could not be read: \(underlyingDescription)"
        case .symbolicLinkReadFailed(let path, let underlyingDescription):
            "The symbolic-link destination for \(path) could not be read: \(underlyingDescription)"
        case .pathEscapedRoot(let file, let root):
            "The discovered file \(file) resolved outside the selected scan root \(root)."
        case .pathResolutionFailed(let path, let underlyingDescription):
            "The canonical path for \(path) could not be resolved safely: \(underlyingDescription)"
        }
    }
}
