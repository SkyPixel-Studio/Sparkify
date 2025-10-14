import Foundation

enum PromptTagPolicy {
    static let agentContextDisplayTag = "代理上下文"
    static let agentContextEnglishTag = "Agent Context"

    static let reservedTags: Set<String> = [
        agentContextDisplayTag,
        agentContextEnglishTag
    ]

    private static let normalizationLocale = Locale(identifier: "en_US_POSIX")
    private static let reservedTagKeys: Set<String> = {
        Set(reservedTags.map { normalizedKey(for: $0) })
    }()

    static func normalize(_ tags: [String], for kind: PromptItem.Kind) -> [String] {
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        let deduped = deduplicatePreservingOrder(cleaned.filter { isReservedTag($0) == false })

        if kind == .agentContext {
            return [agentContextDisplayTag] + deduped
        } else {
            return deduped
        }
    }

    static func removingReservedTags(from tags: [String]) -> [String] {
        deduplicatePreservingOrder(tags.filter { isReservedTag($0) == false })
    }

    static func isReservedTag(_ tag: String) -> Bool {
        reservedTagKeys.contains(normalizedKey(for: tag))
    }

    private static func deduplicatePreservingOrder(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for tag in tags {
            let key = normalizedKey(for: tag)
            if seen.insert(key).inserted {
                result.append(tag)
            }
        }
        return result
    }

    private static func normalizedKey(for tag: String) -> String {
        tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: normalizationLocale)
    }
}
