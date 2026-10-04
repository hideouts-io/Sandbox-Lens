import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List(selection: $model.selectedDestination) {
            Section("Review") {
                sidebarRow(.overview, count: nil)
                sidebarRow(.allProfiles, count: model.comparisons.isEmpty ? nil : model.comparisons.count)
            }

            Section("Findings") {
                sidebarRow(.changed, count: model.count(status: .changed))
                sidebarRow(.missing, count: model.count(status: .missing))
                sidebarRow(.unexpected, count: model.count(status: .unexpected))
            }

            Section("Reference") {
                sidebarRow(.baselines, count: model.releases.count)
                sidebarRow(.learn, count: nil)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            scanStatus
        }
    }

    private func sidebarRow(_ destination: SidebarDestination, count: Int?) -> some View {
        HStack(spacing: 9) {
            Image(systemName: destination.symbolName)
                .frame(width: 18)
            Text(destination.title)
            Spacer()
            if let count {
                Text(count.formatted())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .tag(destination)
    }

    @ViewBuilder
    private var scanStatus: some View {
        if model.isScanning {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Reading profiles…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(.bar)
        }
    }
}
