import Foundation

struct TemplateEngine {
    struct RenderResult {
        let rendered: String
        let missingKeys: [String]
    }

    static func placeholders(in template: String) -> [String] {
        let sanitized = sanitize(template)
        guard let regex = placeholderRegex else { return [] }
        let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
        let matches = regex.matches(in: sanitized, range: range)

        var seen = Set<String>()
        var ordered: [String] = []

        for match in matches {
            guard match.numberOfRanges == 2,
                  let range = Range(match.range(at: 1), in: sanitized) else { continue }
            let key = String(sanitized[range])
            if seen.insert(key).inserted {
                ordered.append(key)
            }
        }
        return ordered
    }

    static func render(template: String, values: [String: String]) -> RenderResult {
        var output = ""
        var missingOrdered: [String] = []
        var missingSet = Set<String>()

        var index = template.startIndex

        while index < template.endIndex {
            let character = template[index]

            if character == "{" {
                let nextIndex = template.index(after: index)
                if nextIndex < template.endIndex, template[nextIndex] == "{" {
                    output.append("{")
                    index = template.index(index, offsetBy: 2)
                    continue
                }

                if let (placeholder, advancedIndex) = readPlaceholder(in: template, from: index) {
                    if let value = values[placeholder] {
                        output.append(value)
                    } else {
                        output.append("{\(placeholder)}")
                        if missingSet.insert(placeholder).inserted {
                            missingOrdered.append(placeholder)
                        }
                    }
                    index = advancedIndex
                    continue
                }

                output.append("{")
                index = template.index(after: index)
                continue
            }

            if character == "}" {
                let nextIndex = template.index(after: index)
                if nextIndex < template.endIndex, template[nextIndex] == "}" {
                    output.append("}")
                    index = template.index(index, offsetBy: 2)
                } else {
                    output.append("}")
                    index = template.index(after: index)
                }
                continue
            }

            output.append(character)
            index = template.index(after: index)
        }

        return RenderResult(rendered: output, missingKeys: missingOrdered)
    }

    static func restoreEscapedBraces(in template: String) -> String {
        template
            .replacingOccurrences(of: "{{", with: "{")
            .replacingOccurrences(of: "}}", with: "}")
    }

    private static func readPlaceholder(in template: String, from start: String.Index) -> (String, String.Index)? {
        var current = template.index(after: start)
        if current >= template.endIndex { return nil }

        var key = ""

        while current < template.endIndex {
            let character = template[current]

            if character == "}" {
                return key.isEmpty ? nil : (key, template.index(after: current))
            }

            guard character.isLetter || character.isNumber || character == "_" else {
                return nil
            }

            key.append(character)
            current = template.index(after: current)
        }

        return nil
    }

    private static func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "{{", with: leftBraceToken)
            .replacingOccurrences(of: "}}", with: rightBraceToken)
    }

    private static let leftBraceToken = "\u{0001}"
    private static let rightBraceToken = "\u{0002}"

    private static let placeholderRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\{([A-Za-z0-9_]+)\}"#, options: [])
    }()
}
