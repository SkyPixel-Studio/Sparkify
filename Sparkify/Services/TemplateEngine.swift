import Foundation

struct TemplateEngine {
    struct RenderResult {
        let rendered: String
        let missingKeys: [String]
    }

    struct PlaceholderDescriptor: Equatable {
        enum Kind: Equatable {
            case text
            case enumeration(options: [String])
        }

        let key: String
        let kind: Kind
        /// 原始占位内容（未归一化、去掉花括号）
        let literalContent: String

        var options: [String] {
            if case let .enumeration(options) = kind {
                return options
            }
            return []
        }

        fileprivate var normalizedPlaceholderSyntax: String {
            switch kind {
            case .text:
                return "{\(key)}"
            case .enumeration(let options):
                guard options.isEmpty == false else { return "{\(key)}" }
                let joined = options.joined(separator: "|")
                return "{\(key):\(joined)}"
            }
        }
    }

    static func placeholders(in template: String) -> [String] {
        placeholderDescriptors(in: template).map(\.key)
    }

    static func placeholderDescriptors(in template: String) -> [PlaceholderDescriptor] {
        let sanitized = sanitize(template)
        var descriptors: [PlaceholderDescriptor] = []
        var seenKeys = Set<String>()

        var index = sanitized.startIndex
        while index < sanitized.endIndex {
            let character = sanitized[index]
            if character == "{" {
                let nextIndex = sanitized.index(after: index)
                if nextIndex < sanitized.endIndex, sanitized[nextIndex] == "{" {
                    index = sanitized.index(index, offsetBy: 2)
                    continue
                }

                if let (descriptor, advancedIndex) = readPlaceholder(in: sanitized, from: index) {
                    if seenKeys.insert(descriptor.key).inserted {
                        descriptors.append(descriptor)
                    }
                    index = advancedIndex
                    continue
                }
            }

            index = sanitized.index(after: index)
        }

        return descriptors
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

                if let (descriptor, advancedIndex) = readPlaceholder(in: template, from: index) {
                    let key = descriptor.key
                    if let value = values[key] {
                        output.append(value)
                    } else {
                        output.append(descriptor.normalizedPlaceholderSyntax)
                        if missingSet.insert(key).inserted {
                            missingOrdered.append(key)
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

    static func rewrite(template: String, with descriptors: [PlaceholderDescriptor]) -> String {
        let lookup = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.key, $0) })
        var output = ""
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

                if let (descriptor, advancedIndex) = readPlaceholder(in: template, from: index) {
                    if let replacement = lookup[descriptor.key] {
                        output.append(replacement.normalizedPlaceholderSyntax)
                    } else {
                        output.append(descriptor.normalizedPlaceholderSyntax)
                    }
                    index = advancedIndex
                    continue
                }
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

        return output
    }

    private static func readPlaceholder(in template: String, from start: String.Index) -> (PlaceholderDescriptor, String.Index)? {
        var current = template.index(after: start)
        if current >= template.endIndex { return nil }

        var buffer = ""

        while current < template.endIndex {
            let character = template[current]

            if character == "}" {
                guard let descriptor = makeDescriptor(from: buffer) else { return nil }
                return (descriptor, template.index(after: current))
            }

            if character == "{" || character.isNewline {
                return nil
            }

            buffer.append(character)
            current = template.index(after: current)
        }

        return nil
    }

    private static func makeDescriptor(from rawContent: String) -> PlaceholderDescriptor? {
        let trimmedContent = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.isEmpty == false else { return nil }

        let parts = trimmedContent.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawKey = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawKey.isEmpty == false,
              isValidKey(rawKey) else {
            return nil
        }

        if parts.count == 1 {
            return PlaceholderDescriptor(key: rawKey, kind: .text, literalContent: rawContent)
        }

        let optionsString = String(parts[1])
        let parsedOptions = parseOptions(optionsString)

        if parsedOptions.isEmpty {
            return PlaceholderDescriptor(key: rawKey, kind: .text, literalContent: rawContent)
        }

        return PlaceholderDescriptor(key: rawKey, kind: .enumeration(options: parsedOptions), literalContent: rawContent)
    }

    private static func parseOptions(_ optionsString: String) -> [String] {
        let candidates = optionsString
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var seen = Set<String>()
        var normalized: [String] = []
        for candidate in candidates {
            guard candidate.isEmpty == false else { continue }
            if seen.insert(candidate).inserted {
                normalized.append(candidate)
            }
        }
        return normalized
    }

    private static func isValidKey(_ key: String) -> Bool {
        guard key.isEmpty == false else { return false }
        return key.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_"
        }
    }

    private static func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "{{", with: leftBraceToken)
            .replacingOccurrences(of: "}}", with: rightBraceToken)
    }

    private static let leftBraceToken = "\u{0001}"
    private static let rightBraceToken = "\u{0002}"
}
