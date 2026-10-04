import Foundation

enum ProfileTextAnalyzer {
    static func analyze(data: Data, sourcePath: String) throws -> ProfileAnalysis {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ProfileAnalysisError.invalidUTF8(path: sourcePath)
        }
        let uncommentedText = removingLineComments(text: text)

        return ProfileAnalysis(
            allowCount: try countMatches(pattern: #"\(allow(?:\s|\()"#, text: uncommentedText),
            denyCount: try countMatches(pattern: #"\(deny(?:\s|\()"#, text: uncommentedText),
            imports: try importedProfiles(text: uncommentedText),
            hasDenyDefault: try contains(pattern: #"\(deny\s+default\b"#, text: uncommentedText),
            hasAllowDefault: try contains(pattern: #"\(allow\s+default\b"#, text: uncommentedText),
            hasGlobalFileRead: try contains(
                pattern: #"\(allow\s+file-read\*\s*\)"#,
                text: uncommentedText
            ),
            hasGlobalFileWrite: try contains(
                pattern: #"\(allow\s+file-write\*\s*\)"#,
                text: uncommentedText
            ),
            hasGlobalFileReadWrite: try contains(
                pattern: #"\(allow\s+file-read\*\s+file-write\*\s*\)"#,
                text: uncommentedText
            ),
            hasGlobalProcessExec: try contains(
                pattern: #"\(allow\s+process-exec\s*\)"#,
                text: uncommentedText
            ),
            hasGlobalNetwork: try contains(
                pattern: #"\(allow\s+network\*\s*\)"#,
                text: uncommentedText
            ),
            hasNoSandboxExecution: uncommentedText.contains("(with no-sandbox)")
        )
    }

    private static func removingLineComments(text: String) -> String {
        var result = ""
        var isInsideString = false
        var isEscaped = false
        var isInsideComment = false

        for character in text {
            if isInsideComment {
                if character.isNewline {
                    isInsideComment = false
                    result.append(character)
                }
                continue
            }

            if isInsideString {
                result.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            if character == ";" {
                isInsideComment = true
            } else {
                result.append(character)
                if character == "\"" {
                    isInsideString = true
                }
            }
        }

        return result
    }

    private static func contains(pattern: String, text: String) throws -> Bool {
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }

    private static func countMatches(pattern: String, text: String) throws -> Int {
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.numberOfMatches(in: text, range: range)
    }

    private static func importedProfiles(text: String) throws -> [String] {
        let expression = try NSRegularExpression(pattern: #"\(import\s+\"([^\"]+)\"\)"#)
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let imports = expression.matches(in: text, range: fullRange).compactMap { match -> String? in
            guard match.numberOfRanges == 2,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range])
        }
        return Array(Set(imports)).sorted()
    }
}

enum ProfileAnalysisError: LocalizedError {
    case invalidUTF8(path: String)

    var errorDescription: String? {
        switch self {
        case .invalidUTF8(let path):
            "The sandbox profile at \(path) is not valid UTF-8 text. It was not interpreted as an SBPL profile."
        }
    }
}
