import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                if let scanResult = model.scanResult {
                    verdictBanner(scanResult: scanResult)
                    summaryGrid
                } else {
                    gettingStarted
                }
                corpusSummary
            }
            .padding(22)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("SandboxLensMark", bundle: .module)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityLabel("Sandbox Lens")
                .accessibilityIdentifier("branding.overview.mark")
            Text("Understand your Mac's sandbox rules")
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Sandbox Lens reads Apple Sandbox Profile Language files, fingerprints them, and explains how they compare with a selected macOS release.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
            MetricCard(
                title: "Matches",
                value: model.count(status: .match),
                symbol: "checkmark.circle.fill",
                color: .green
            )
            MetricCard(
                title: "Different",
                value: model.count(status: .changed),
                symbol: "exclamationmark.triangle.fill",
                color: .orange
            )
            MetricCard(
                title: "Missing",
                value: model.count(status: .missing),
                symbol: "questionmark.circle.fill",
                color: .yellow
            )
            MetricCard(
                title: "Additional",
                value: model.count(status: .unexpected),
                symbol: "plus.circle.fill",
                color: .blue
            )
        }
    }

    private func verdictBanner(scanResult: ScanResult) -> some View {
        let verdict = scanVerdict(scanResult: scanResult)
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: verdict.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(verdict.color)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 6) {
                Text(verdict.title)
                    .font(.title2.weight(.semibold))
                Text(verdict.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(verdict.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(verdict.color.opacity(0.30), lineWidth: 1)
        }
    }

    private func scanVerdict(scanResult: ScanResult) -> ScanVerdict {
        guard let baseline = model.selectedBaseline else {
            return ScanVerdict(
                title: "This comparison is inconclusive",
                message: "No reference version is selected. The files were inventoried, but the app cannot determine whether they match an expected macOS release.",
                symbol: "questionmark.circle.fill",
                color: .secondary
            )
        }

        guard model.exactBaselineSelected else {
            let currentSystem = model.systemIdentity?.displayName ?? "this Mac's installed version"
            return ScanVerdict(
                title: "This comparison is inconclusive",
                message: "The selected reference, \(baseline.displayName), does not exactly match \(currentSystem). OS-version differences can be ordinary, so these results are not a definitive verdict.",
                symbol: "info.circle.fill",
                color: .blue
            )
        }

        let changedCount = model.count(status: .changed)
        let missingCount = model.count(status: .missing)
        let additionalCount = model.count(status: .unexpected)
        let findingCount = changedCount + missingCount + additionalCount
        if findingCount == 0 {
            return ScanVerdict(
                title: "Everything matches this exact macOS reference",
                message: "All \(scanResult.profiles.count.formatted()) readable profiles match \(baseline.displayName). This scan found no sandbox-profile differences that need review.",
                symbol: "checkmark.seal.fill",
                color: .green
            )
        }

        let noun = findingCount == 1 ? "file needs" : "files need"
        let findingSummary = [
            findingLabel(count: changedCount, label: "changed"),
            findingLabel(count: missingCount, label: "missing"),
            findingLabel(count: additionalCount, label: "additional")
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
        return ScanVerdict(
            title: "\(findingCount.formatted()) \(noun) review",
            message: "The exact reference comparison found \(findingSummary). These are review findings, not proof of malware or compromise.",
            symbol: "exclamationmark.triangle.fill",
            color: .orange
        )
    }

    private func findingLabel(count: Int, label: String) -> String? {
        guard count > 0 else {
            return nil
        }
        return "\(count.formatted()) \(label)"
    }

    private var gettingStarted: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Start with a read-only scan")
                    .font(.headline)
                Text("The scan checks standard protected system locations. It does not execute profiles, change permissions, quarantine files, or upload data.")
                    .foregroundStyle(.secondary)
                Button {
                    Task {
                        await model.scanThisMac()
                    }
                } label: {
                    Label("Scan This Mac", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isScanning || model.catalog == nil)
            }
        }
    }

    private var corpusSummary: some View {
        Panel {
            VStack(alignment: .leading, spacing: 7) {
                Label("Reference library", systemImage: "books.vertical.fill")
                    .font(.headline)
                Text("\(model.releases.count) sourced snapshots spanning macOS 10.9.5 through the current local build. The app labels source and confidence and does not pretend that every Apple point release is publicly archived.")
                    .foregroundStyle(.secondary)
                Button("Review baseline coverage") {
                    model.selectedDestination = .baselines
                }
                .buttonStyle(.link)
            }
        }
    }
}

private struct ScanVerdict {
    let title: String
    let message: String
    let symbol: String
    let color: Color
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(value.formatted())
                .font(.title.weight(.bold).monospacedDigit())
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WelcomeDetailView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            if model.scanResult == nil {
                Image("SandboxLensMark", bundle: .module)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityLabel("Sandbox Lens")
                    .accessibilityIdentifier("branding.welcome.mark")
            } else {
                Image(systemName: "checklist")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.blue)
            }
            Text(model.scanResult == nil ? "A calm, evidence-based review" : "Scan complete")
                .font(.title.weight(.semibold))
            Text(detailText)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let scanResult = model.scanResult {
                Divider()
                LabeledContent("Profiles read", value: scanResult.profiles.count.formatted())
                LabeledContent("Completed", value: scanResult.completedAt.formatted(date: .abbreviated, time: .standard))
            }
            Spacer()
        }
        .frame(maxWidth: 500, alignment: .leading)
        .padding(40)
    }

    private var detailText: String {
        if model.scanResult == nil {
            return "A difference can be completely ordinary after an operating-system update. Sandbox Lens separates exact matches, changes, missing files, and additional files so you can review evidence without alarmist conclusions."
        }
        return "Open Different, Missing, or Additional in the sidebar to inspect individual findings and see what each result can—and cannot—mean."
    }
}
