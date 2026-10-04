import Foundation

enum ComparisonEngine {
    static func compare(
        scannedProfiles: [ScannedProfile],
        baseline: BaselineRelease
    ) -> [ProfileComparison] {
        let baselineByPath = Dictionary(uniqueKeysWithValues: baseline.profiles.map { ($0.relativePath, $0) })
        let baselineByName = Dictionary(grouping: baseline.profiles, by: \.fileName)
        let scannedByName = Dictionary(grouping: scannedProfiles, by: \.fileName)
        var matchedBaselinePaths = Set<String>()
        var comparisons: [ProfileComparison] = []

        for scanned in scannedProfiles {
            let exactBaseline = baselineByPath[scanned.relativePath]
            let nameBaseline: BaselineProfile?
            if baselineByName[scanned.fileName]?.count == 1,
               scannedByName[scanned.fileName]?.count == 1 {
                nameBaseline = baselineByName[scanned.fileName]?.first
            } else {
                nameBaseline = nil
            }

            let selectedBaseline = exactBaseline ?? nameBaseline
            let method: ComparisonMethod = exactBaseline == nil ?
                (nameBaseline == nil ? .none : .uniqueFileName) : .exactPath

            guard let selectedBaseline else {
                comparisons.append(
                    ProfileComparison(
                        id: "scanned:\(scanned.relativePath)",
                        relativePath: scanned.relativePath,
                        fileName: scanned.fileName,
                        status: .unexpected,
                        method: .none,
                        scanned: scanned,
                        baseline: nil,
                        changes: []
                    )
                )
                continue
            }

            matchedBaselinePaths.insert(selectedBaseline.relativePath)
            let metadataMatches = scanned.isSymbolicLink == selectedBaseline.isSymbolicLink &&
                scanned.symbolicLinkTarget == selectedBaseline.symbolicLinkTarget
            let status: ComparisonStatus = scanned.sha256 == selectedBaseline.sha256 && metadataMatches ?
                .match : .changed
            comparisons.append(
                ProfileComparison(
                    id: "compared:\(selectedBaseline.relativePath)",
                    relativePath: scanned.relativePath,
                    fileName: scanned.fileName,
                    status: status,
                    method: method,
                    scanned: scanned,
                    baseline: selectedBaseline,
                    changes: status == .changed ? describeChanges(
                        scanned: scanned,
                        baseline: selectedBaseline
                    ) : []
                )
            )
        }

        for baselineProfile in baseline.profiles where !matchedBaselinePaths.contains(baselineProfile.relativePath) {
            comparisons.append(
                ProfileComparison(
                    id: "missing:\(baselineProfile.relativePath)",
                    relativePath: baselineProfile.relativePath,
                    fileName: baselineProfile.fileName,
                    status: .missing,
                    method: .exactPath,
                    scanned: nil,
                    baseline: baselineProfile,
                    changes: []
                )
            )
        }

        return comparisons.sorted {
            if $0.status == $1.status {
                return $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
            }
            return statusOrder($0.status) < statusOrder($1.status)
        }
    }

    static func unverified(scannedProfiles: [ScannedProfile]) -> [ProfileComparison] {
        scannedProfiles.map { scanned in
            ProfileComparison(
                id: "unverified:\(scanned.relativePath)",
                relativePath: scanned.relativePath,
                fileName: scanned.fileName,
                status: .unverified,
                method: .none,
                scanned: scanned,
                baseline: nil,
                changes: []
            )
        }
    }

    private static func describeChanges(
        scanned: ScannedProfile,
        baseline: BaselineProfile
    ) -> [String] {
        var changes: [String] = []
        if scanned.isSymbolicLink != baseline.isSymbolicLink {
            changes.append(
                scanned.isSymbolicLink ?
                    "The scanned path is a symbolic link, but the baseline path is a regular file." :
                    "The baseline path is a symbolic link, but the scanned path is a regular file."
            )
        } else if scanned.symbolicLinkTarget != baseline.symbolicLinkTarget {
            changes.append(
                "Symbolic-link target: baseline \(baseline.symbolicLinkTarget ?? "none"), scanned \(scanned.symbolicLinkTarget ?? "none")."
            )
        }
        appendBooleanChange(
            title: "permissive default",
            scannedValue: scanned.analysis.hasAllowDefault,
            baselineValue: baseline.analysis.hasAllowDefault,
            changes: &changes
        )
        appendBooleanChange(
            title: "deny-by-default policy",
            scannedValue: scanned.analysis.hasDenyDefault,
            baselineValue: baseline.analysis.hasDenyDefault,
            changes: &changes
        )
        appendBooleanChange(
            title: "broad file reading",
            scannedValue: scanned.analysis.hasGlobalFileRead,
            baselineValue: baseline.analysis.hasGlobalFileRead,
            changes: &changes
        )
        appendBooleanChange(
            title: "broad file writing",
            scannedValue: scanned.analysis.hasGlobalFileWrite || scanned.analysis.hasGlobalFileReadWrite,
            baselineValue: baseline.analysis.hasGlobalFileWrite || baseline.analysis.hasGlobalFileReadWrite,
            changes: &changes
        )
        appendBooleanChange(
            title: "broad program execution",
            scannedValue: scanned.analysis.hasGlobalProcessExec,
            baselineValue: baseline.analysis.hasGlobalProcessExec,
            changes: &changes
        )
        appendBooleanChange(
            title: "broad networking",
            scannedValue: scanned.analysis.hasGlobalNetwork,
            baselineValue: baseline.analysis.hasGlobalNetwork,
            changes: &changes
        )
        appendBooleanChange(
            title: "unsandboxed child execution",
            scannedValue: scanned.analysis.hasNoSandboxExecution,
            baselineValue: baseline.analysis.hasNoSandboxExecution,
            changes: &changes
        )

        if scanned.analysis.allowCount != baseline.analysis.allowCount {
            changes.append("Allow-form count: baseline \(baseline.analysis.allowCount), scanned \(scanned.analysis.allowCount).")
        }
        if scanned.analysis.denyCount != baseline.analysis.denyCount {
            changes.append("Deny-form count: baseline \(baseline.analysis.denyCount), scanned \(scanned.analysis.denyCount).")
        }

        let addedImports = Set(scanned.analysis.imports).subtracting(baseline.analysis.imports).sorted()
        let removedImports = Set(baseline.analysis.imports).subtracting(scanned.analysis.imports).sorted()
        if !addedImports.isEmpty {
            changes.append("Added imports: \(addedImports.joined(separator: ", ")).")
        }
        if !removedImports.isEmpty {
            changes.append("Removed imports: \(removedImports.joined(separator: ", ")).")
        }
        if changes.isEmpty {
            changes.append("The text changed without changing the broad capability markers summarized by this app.")
        }
        return changes
    }

    private static func appendBooleanChange(
        title: String,
        scannedValue: Bool,
        baselineValue: Bool,
        changes: inout [String]
    ) {
        if scannedValue && !baselineValue {
            changes.append("The scanned file adds \(title).")
        } else if !scannedValue && baselineValue {
            changes.append("The scanned file removes \(title).")
        }
    }

    private static func statusOrder(_ status: ComparisonStatus) -> Int {
        switch status {
        case .changed: 0
        case .unexpected: 1
        case .missing: 2
        case .unverified: 3
        case .match: 4
        }
    }
}
