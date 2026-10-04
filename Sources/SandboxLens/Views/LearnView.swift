import SwiftUI

struct LearnView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("What this means")
                    .font(.largeTitle.weight(.bold))
                Text("A plain-language guide to Apple sandbox profiles and this app's conclusions.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                LearnSection(
                    symbol: "doc.text",
                    title: "What is an .sb file?",
                    explanation: "It is usually a text policy written in Apple's Sandbox Profile Language. The policy can allow or deny categories of operations—such as opening files, contacting services, or using the network—for a process that loads it."
                )
                LearnSection(
                    symbol: "equal.circle",
                    title: "What does a match prove?",
                    explanation: "An exact SHA-256 match proves that the bytes are the same as the selected sourced copy. It does not prove that Apple signed that individual text file, or that the profile was recently used."
                )
                LearnSection(
                    symbol: "exclamationmark.triangle",
                    title: "Is a difference malicious?",
                    explanation: "Not by itself. Apple changes profiles between builds, and software can install its own profiles. A difference becomes more meaningful when the baseline is an exact build and other evidence—signatures, package receipts, timestamps, or logs—corroborates it."
                )
                LearnSection(
                    symbol: "scope",
                    title: "Capability is not activity",
                    explanation: "A rule describes what could be permitted or denied if the profile is loaded in the relevant context. Static text cannot establish that an operation occurred, a connection was made, or a person controlled the Mac."
                )
                LearnSection(
                    symbol: "lock.shield",
                    title: "What the scanner does",
                    explanation: "It reads .sb files, computes fingerprints, and extracts a small set of broad syntax markers. It does not compile or execute profiles, change files, bypass System Integrity Protection, or send scan results to a server."
                )
            }
            .padding(24)
        }
    }
}

private struct LearnSection: View {
    let symbol: String
    let title: String
    let explanation: String

    var body: some View {
        Panel {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(explanation)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SafetyDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 46))
                .foregroundStyle(.green)
            Text("Local and read-only")
                .font(.title.weight(.semibold))
            Text("Sandbox Lens is designed as an evidence viewer. It makes no repair or removal decisions, because a static policy difference alone is not enough evidence to justify changing a system file.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(40)
    }
}
