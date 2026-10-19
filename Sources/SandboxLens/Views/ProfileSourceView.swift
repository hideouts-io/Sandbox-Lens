import AppKit
import SwiftUI

struct ProfileSourceView: View {
    let comparison: ProfileComparison?
    let scan: ScanResult?

    @State private var sourceState: SourceState = .unavailable

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Source text")
                    .font(.headline)
                Text(comparison?.fileName ?? "No profile selected")
                    .font(.subheadline.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Read only · rechecked against the scan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            switch sourceState {
            case .unavailable:
                EmptyStateView(
                    symbol: "doc.text",
                    title: "No scanned source text",
                    message: comparison == nil
                        ? "Choose a scanned profile to read its .sb text."
                        : "This baseline-only entry has no copied .sb text."
                )
            case .loading:
                ProgressView("Reading selected profile…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let source):
                ReadOnlyProfileTextView(source: source, sourceID: comparison?.scanned?.sha256 ?? "")
            case .failed(let message):
                EmptyStateView(
                    symbol: "exclamationmark.triangle",
                    title: "Source text unavailable",
                    message: message
                )
            }
        }
        .task(id: comparison) {
            guard let comparison, let profile = comparison.scanned, let scan else {
                sourceState = .unavailable
                return
            }
            sourceState = .loading
            let worker = Task.detached(priority: .userInitiated) {
                try ProfileSourceReader.read(profile: profile, scan: scan)
            }
            do {
                let source = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard !Task.isCancelled else {
                    return
                }
                sourceState = .loaded(source)
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                sourceState = .failed(error.localizedDescription)
            }
        }
    }
}

private struct ReadOnlyProfileTextView: NSViewRepresentable {
    let source: String
    let sourceID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.setAccessibilityIdentifier("profile.sourceText")

        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityIdentifier("profile.sourceText.content")
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.sourceID != sourceID,
              let textView = scrollView.documentView as? NSTextView else {
            return
        }
        textView.string = source
        context.coordinator.sourceID = sourceID
        textView.scrollToBeginningOfDocument(nil)
    }

    final class Coordinator {
        var sourceID: String?
    }
}

private enum SourceState {
    case unavailable
    case loading
    case loaded(String)
    case failed(String)
}
