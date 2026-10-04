import SwiftUI

enum VisualStyle {
    static func color(for status: ComparisonStatus) -> Color {
        switch status {
        case .match: .green
        case .changed: .orange
        case .missing: .yellow
        case .unexpected: .blue
        case .unverified: .secondary
        }
    }

    static func symbol(for status: ComparisonStatus) -> String {
        switch status {
        case .match: "checkmark.circle.fill"
        case .changed: "exclamationmark.triangle.fill"
        case .missing: "questionmark.circle.fill"
        case .unexpected: "plus.circle.fill"
        case .unverified: "minus.circle.fill"
        }
    }

    static func byteCount(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}

struct StatusBadge: View {
    let status: ComparisonStatus

    var body: some View {
        Label(status.shortTitle, systemImage: VisualStyle.symbol(for: status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(VisualStyle.color(for: status))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(VisualStyle.color(for: status).opacity(0.12), in: Capsule())
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.separator.opacity(0.45), lineWidth: 1)
            }
    }
}
