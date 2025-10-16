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
    
    /// Returns the localized display name for a tag based on current app language
    /// For the special "Agent Context" tag, returns the appropriate localized version
    static func localizedDisplayName(for tag: String) -> String {
        // Check if this is an agent context tag (Chinese or English variant)
        guard isAgentContextTag(tag) else {
            return tag
        }
        
        // Determine current app language
        let currentLanguageCode = getCurrentLanguageCode()
        
        // Return appropriate localized version
        if currentLanguageCode == "zh-Hans" {
            return agentContextDisplayTag
        } else {
            return agentContextEnglishTag
        }
    }
    
    /// Check if a tag is the agent context tag (either Chinese or English variant)
    private static func isAgentContextTag(_ tag: String) -> Bool {
        let normalizedTag = normalizedKey(for: tag)
        let normalizedChinese = normalizedKey(for: agentContextDisplayTag)
        let normalizedEnglish = normalizedKey(for: agentContextEnglishTag)
        return normalizedTag == normalizedChinese || normalizedTag == normalizedEnglish
    }
    
    /// Get the current app language code
    private static func getCurrentLanguageCode() -> String {
        // Check if user has set a specific language override
        if let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let preferredLanguage = languages.first {
            return preferredLanguage
        }
        
        // Fall back to system language
        return Locale.preferredLanguages.first ?? "en"
    }

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
