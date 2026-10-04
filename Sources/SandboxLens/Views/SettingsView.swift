import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Privacy") {
                Label("Scans stay on this Mac", systemImage: "internaldrive")
                Text("Sandbox Lens does not upload profile text, fingerprints, paths, or results.")
                    .foregroundStyle(.secondary)
            }
            Section("Safety") {
                Label("Read-only inspection", systemImage: "lock.shield")
                Text("The app never compiles, loads, edits, quarantines, or deletes sandbox profiles.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 270)
        .padding()
    }
}
