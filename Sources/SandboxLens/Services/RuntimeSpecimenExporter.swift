import Darwin
import Foundation

enum RuntimeSpecimenExporter {
    static let policyWitnessReference = RuntimeSpecimenPolicyWitnessReference(
        repositoryURL: "https://github.com/Protonk/PolicyWitness",
        revision: "4a032db9e5b0d940f9a2ad821ac3689db11da0d0",
        requestSchemaVersion: 4,
        responseSchemaVersion: 14,
        controllerEnvelopeSchemaVersion: 7
    )

    /// Copies verified source bytes and static evidence; never compiles or executes policy.
    static func export(
        comparison: ProfileComparison,
        scan: ScanResult,
        baseline: BaselineRelease?,
        host: SystemIdentity,
        app: RuntimeSpecimenAppIdentity,
        destination: URL,
        exportedAt: Date
    ) throws {
        guard let scanned = comparison.scanned else {
            throw RuntimeSpecimenError.sourceUnavailable
        }
        guard scan.profiles.contains(scanned) else {
            throw RuntimeSpecimenError.sourceNotInScan(path: scanned.fileURL.path)
        }
        let root = try sourceRoot(profile: scanned, roots: scan.roots)
        let accessed = root.url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                root.url.stopAccessingSecurityScopedResource()
            }
        }

        let read = try ProfileScanner().readProfile(fileURL: scanned.fileURL, root: root)
        guard read.profile.sha256 == scanned.sha256 else {
            throw RuntimeSpecimenError.sourceChanged(
                path: scanned.fileURL.path,
                expected: scanned.sha256,
                actual: read.profile.sha256
            )
        }
        guard read.profile == scanned else {
            throw RuntimeSpecimenError.sourceMetadataChanged(path: scanned.fileURL.path)
        }

        let manifest = RuntimeSpecimenManifest(
            schemaVersion: 1,
            exportedAt: exportedAt,
            app: app,
            scanningHost: host,
            scan: RuntimeSpecimenScan(startedAt: scan.startedAt, completedAt: scan.completedAt),
            source: RuntimeSpecimenSource(
                relativePath: scanned.relativePath,
                fileName: scanned.fileName,
                fileURL: scanned.fileURL,
                scanRootURL: root.url,
                sha256: scanned.sha256,
                sizeBytes: scanned.sizeBytes,
                isSymbolicLink: scanned.isSymbolicLink,
                symbolicLinkTarget: scanned.symbolicLinkTarget,
                originatingSystem: nil
            ),
            comparison: RuntimeSpecimenComparison(
                status: comparison.status,
                method: comparison.method,
                changes: comparison.changes,
                matchedBaseline: comparison.baseline
            ),
            selectedBaseline: baseline.map { RuntimeSpecimenBaseline(release: $0) },
            staticAnalysis: scanned.analysis,
            runtimeObservation: .notPerformed,
            policyWitnessReference: policyWitnessReference
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let files: [(name: String, data: Data)] = [
            ("profile.sb", read.data),
            ("manifest.json", try encoder.encode(manifest)),
            ("README.txt", Data(readme.utf8))
        ]
        let checksums = files.map { file in
            "\(ProfileScanner.sha256(data: file.data))  \(file.name)\n"
        }.joined()
        try publish(
            files: files + [("sha256.txt", Data(checksums.utf8))],
            destination: destination
        )
    }

    private static func sourceRoot(profile: ScannedProfile, roots: [ScanRoot]) throws -> ScanRoot {
        let filePath = profile.fileURL.standardizedFileURL.path
        let matches = roots.filter { root in
            let rootPath = root.url.standardizedFileURL.path
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            return filePath.hasPrefix(prefix) &&
                profile.relativePath == root.baselinePrefix + "/" + filePath.dropFirst(prefix.count)
        }
        guard matches.count == 1, let root = matches.first else {
            throw RuntimeSpecimenError.sourceRootUnavailable(path: filePath)
        }
        return root
    }

    /// Publishes only a complete folder, using an exclusive same-directory rename.
    private static func publish(files: [(name: String, data: Data)], destination: URL) throws {
        var entry = stat()
        let result = destination.path.withCString { lstat($0, &entry) }
        if result == 0 {
            throw RuntimeSpecimenError.destinationExists(path: destination.path)
        }
        let lookupError = errno
        guard lookupError == ENOENT else {
            throw RuntimeSpecimenError.destinationUnavailable(path: destination.path, errnoValue: lookupError)
        }

        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".SandboxLens-specimen-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: staging,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw RuntimeSpecimenError.writeFailed(path: staging.path, reason: error.localizedDescription)
        }

        do {
            for file in files {
                let output = staging.appendingPathComponent(file.name)
                do {
                    try file.data.write(to: output, options: [.withoutOverwriting])
                } catch {
                    throw RuntimeSpecimenError.writeFailed(path: output.path, reason: error.localizedDescription)
                }
            }
            let renameResult = staging.path.withCString { source in
                destination.path.withCString { target in
                    renamex_np(source, target, UInt32(RENAME_EXCL))
                }
            }
            guard renameResult == 0 else {
                let renameError = errno
                if renameError == EEXIST {
                    throw RuntimeSpecimenError.destinationExists(path: destination.path)
                }
                throw RuntimeSpecimenError.publishFailed(path: destination.path, errnoValue: renameError)
            }
        } catch {
            let primaryError = error
            do {
                try FileManager.default.removeItem(at: staging)
            } catch {
                throw RuntimeSpecimenError.cleanupFailed(
                    path: staging.path,
                    primaryReason: primaryError.localizedDescription,
                    cleanupReason: error.localizedDescription
                )
            }
            throw primaryError
        }
    }

    private static var readme: String {
        let reference = policyWitnessReference
        let inspectedSource = "\(reference.repositoryURL)/blob/\(reference.revision)"
        return """
        Sandbox Lens runtime research specimen

        This folder contains static evidence for researcher-managed external testing.
        Runtime observation: not performed. No policy was compiled, applied or run,
        and no sandbox_check prediction or attempted-operation evidence was collected.

        Files and verification
        profile.sb contains the exact source bytes verified against the scan hash.
        It is a regular file even if the scanned source was a symbolic link.
        manifest.json is Sandbox Lens export metadata (schemaVersion 1), NOT a
        runnable PolicyWitness request. sha256.txt covers profile.sb, manifest.json
        and this README, without self-reference. From this folder, verify with:
            shasum -a 256 -c sha256.txt
        Hashes establish byte integrity; they do not authenticate the source.

        Provenance and unavailable facts
        The manifest records app identity, the scanning host, scan/export times,
        source path/hash/size/link metadata, comparison and selected baseline provenance.
        Dates are UTC Unix milliseconds. Null means unavailable, not a negative finding.
        source.originatingSystem is unknown: neither the scanning host nor the selected
        reference establishes the source profile's originating OS build. Baseline
        confidence and notes describe the reference source, not runtime authorization.
        staticAnalysis is a narrow textual summary; its imports are unresolved markers.

        External research handoff
        1. Verify the files and review provenance, including the source/reference builds.
        2. Consult the inspected PolicyWitness guide, contract and limits:
           \(inspectedSource)/docs/PolicyWitness.md
           \(inspectedSource)/docs/contract.json
           \(inspectedSource)/docs/LIMITS.md
        3. Outside Sandbox Lens, author a separate request containing the SBPL source
           in policy.sbpl_source, a specimen identity and your own probe_plan. No
           probe plan is supplied here. Select a runner and signed entitlement context
           appropriate to your question; Sandbox Lens does not collect runner facts.
        4. Resolve required imports and parameters externally. This file may be an
           imported support fragment rather than a standalone runnable policy.
        5. Check the installed tool's current contract and admission limits. Export
           success does not establish PolicyWitness compatibility or portability.

        Inspected PolicyWitness revision: \(reference.revision)
        Request schema: \(reference.requestSchemaVersion); response schema: \(reference.responseSchemaVersion);
        controller envelope schema: \(reference.controllerEnvelopeSchemaVersion).
        These are separate from Sandbox Lens's export schema.

        Evidence discipline shared across Hideouts
        declared entitlement ≠ authorization
        sandbox policy ≠ observed behavior
        exit status ≠ completed operation
        timestamp proximity ≠ causation
        vulnerability exposure ≠ compromise

        Keep sandbox_check predictions and attempted-operation observations separate.
        A failed operation alone does not establish sandbox denial. Apparent differences
        require examining permissions, runtime target identity, changing state and
        other causes. Nearby denial logs supply candidates, not proof of causation.
        """ + "\n"
    }
}

enum RuntimeSpecimenError: LocalizedError {
    case sourceUnavailable
    case sourceNotInScan(path: String)
    case sourceRootUnavailable(path: String)
    case sourceChanged(path: String, expected: String, actual: String)
    case sourceMetadataChanged(path: String)
    case invalidAppMetadata(key: String, bundlePath: String)
    case destinationExists(path: String)
    case destinationUnavailable(path: String, errnoValue: Int32)
    case writeFailed(path: String, reason: String)
    case publishFailed(path: String, errnoValue: Int32)
    case cleanupFailed(path: String, primaryReason: String, cleanupReason: String)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            "The selected row has no scanned source bytes. Select a scanned profile; baseline-only and missing rows cannot be exported."
        case .sourceNotInScan(let path):
            "The selected profile is not part of the captured scan: \(path). Scan again before exporting."
        case .sourceRootUnavailable(let path):
            "No unique captured scan root contains \(path). Scan again before exporting."
        case .sourceChanged(let path, let expected, let actual):
            "The source \(path) changed since the scan. Expected SHA-256 \(expected); read \(actual). Scan again before exporting."
        case .sourceMetadataChanged(let path):
            "The source metadata or symbolic link changed since the scan: \(path). Scan again before exporting."
        case .invalidAppMetadata(let key, let bundlePath):
            "App metadata \(key) must be a nonempty string in \(bundlePath). Rebuild the app bundle before exporting."
        case .destinationExists(let path):
            "The export destination already exists: \(path). Choose a new folder name; existing files are never replaced."
        case .destinationUnavailable(let path, let errnoValue):
            "The export destination \(path) could not be inspected: errno=\(errnoValue) (\(String(cString: strerror(errnoValue))))."
        case .writeFailed(let path, let reason):
            "The specimen could not be written at \(path): \(reason) No completed export was published."
        case .publishFailed(let path, let errnoValue):
            "The completed specimen could not be published at \(path): errno=\(errnoValue) (\(String(cString: strerror(errnoValue))))."
        case .cleanupFailed(let path, let primaryReason, let cleanupReason):
            "Export failed: \(primaryReason) Its temporary folder \(path) could not be removed: \(cleanupReason) No completed export was published."
        }
    }
}
