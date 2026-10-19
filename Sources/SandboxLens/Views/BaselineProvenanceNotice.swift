import SwiftUI

struct BaselineProvenanceNotice: View {
    let provenance: BaselineProvenance
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(.orange)
                Text(provenance.attribution == .conflicting
                    ? "Conflicting source version reports"
                    : "Reference attribution is not independently verified")
                    .font(.headline)
                    .accessibilityIdentifier(identifier)
            }
            Text("Version and build are source declarations. Saved-byte matches do not independently establish Apple authenticity, complete policy coverage, or runtime authorization.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
