import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var isImportingFolder = false
    @State private var isShowingFolderGuide = false

    var body: some View {
        HSplitView {
            SidebarView(model: model)
                .frame(minWidth: 190, idealWidth: 220, maxWidth: 260)

            middleColumn
                .frame(minWidth: 310, idealWidth: 390, maxWidth: 480)

            detailColumn
                .frame(minWidth: 430, maxWidth: .infinity)
        }
        .navigationTitle("Sandbox Lens")
        .toolbar {
            ToolbarItemGroup {
                baselinePicker
                Button {
                    Task {
                        await model.scanThisMac()
                    }
                } label: {
                    Label("Scan This Mac", systemImage: "play.circle.fill")
                }
                .disabled(model.isScanning || model.isExporting || model.catalog == nil)

                Button {
                    isShowingFolderGuide = true
                } label: {
                    Label("Scan Copied Folder", systemImage: "folder.badge.plus")
                }
                .disabled(model.isScanning || model.isExporting || model.catalog == nil)
                .help("Choose a folder that directly contains copied .sb files")
                .accessibilityIdentifier("scan.copiedFolder")

                Menu {
                    Button("Runtime research specimen…") {
                        Task {
                            await model.exportRuntimeResearchSpecimen()
                        }
                    }
                    .accessibilityIdentifier("export.runtimeResearchSpecimen")
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("export.menu")
                .disabled(!model.canExportRuntimeResearchSpecimen)
                .help(model.runtimeSpecimenExportHelp)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let url = model.runtimeSpecimenExportURL {
                Label("Exported specimen: \(url.path)", systemImage: "checkmark.circle")
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .accessibilityIdentifier("export.runtimeResearchSpecimen.success")
            }
        }
        .fileImporter(
            isPresented: $isImportingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $isShowingFolderGuide) {
            FolderScanGuide(
                chooseFolderAction: {
                    isShowingFolderGuide = false
                    isImportingFolder = true
                },
                scanMacAction: {
                    isShowingFolderGuide = false
                    Task {
                        await model.scanThisMac()
                    }
                },
                cancelAction: {
                    isShowingFolderGuide = false
                }
            )
        }
        .alert("Sandbox Lens could not complete the operation", isPresented: errorPresented) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
    }

    @ViewBuilder
    private var middleColumn: some View {
        switch model.selectedDestination {
        case .overview:
            OverviewView(model: model)
        case .baselines:
            BaselineLibraryView(model: model)
        case .learn:
            LearnView()
        case .allProfiles, .changed, .missing, .unexpected:
            ComparisonListView(model: model)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch model.selectedDestination {
        case .allProfiles, .changed, .missing, .unexpected:
            ProfileDetailView(comparison: model.visibleSelectedComparison, baseline: model.selectedBaseline) {
                model.revealSelectedProfile()
            }
        case .baselines:
            BaselineDetailView(release: model.selectedBaseline)
        case .overview:
            WelcomeDetailView(model: model)
        case .learn:
            SafetyDetailView()
        }
    }

    private var baselinePicker: some View {
        Picker("Baseline", selection: $model.selectedBaselineID) {
            Text("No baseline").tag(String?.none)
            ForEach(model.releases) { release in
                Text(release.displayName).tag(Optional(release.id))
            }
        }
        .pickerStyle(.menu)
        .help("Choose the exact macOS release and build when possible")
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { value in
                if !value {
                    model.errorMessage = nil
                }
            }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folder = urls.first else {
                model.errorMessage = "No folder was selected."
                return
            }
            Task {
                await model.scanFolder(url: folder)
            }
        case .failure(let error):
            model.errorMessage = "The folder picker failed: \(error.localizedDescription)"
        }
    }
}

private struct FolderScanGuide: View {
    let chooseFolderAction: () -> Void
    let scanMacAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 34))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Which folder should I choose?")
                        .font(.title2.weight(.semibold))
                    Text("Choose the folder that directly contains the copied .sb files—not the whole System or Library folder.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("For your external collection", systemImage: "externaldrive")
                    .font(.headline)
                Text("Choose the folder named sandbox (or another folder that directly contains the copied .sb files).")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("For Apple files already on this Mac", systemImage: "desktopcomputer")
                    .font(.headline)
                Text("Use Scan This Mac. It safely checks both standard Apple sandbox folders without entering unrelated protected directories.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel", action: cancelAction)
                Spacer()
                Button("Scan This Mac", action: scanMacAction)
                Button("Choose Copied Folder…", action: chooseFolderAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("scan.chooseCopiedFolder")
            }
        }
        .padding(24)
        .frame(width: 540)
    }
}
