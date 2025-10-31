import Foundation
import SwiftData

enum PromptParamType: String, Codable, CaseIterable {
    case text
    case enumeration
    case toggle
}

struct RevisionParamSnapshot: Codable, Equatable {
    let key: String
    let value: String
    let defaultValue: String?
    let type: PromptParamType
    let options: [String]

    init(
        key: String,
        value: String,
        defaultValue: String?,
        type: PromptParamType = .text,
        options: [String] = []
    ) {
        self.key = key
        self.value = value
        self.defaultValue = defaultValue
        self.type = type
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case value
        case defaultValue
        case type
        case options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        value = try container.decode(String.self, forKey: .value)
        defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
        if let rawType = try container.decodeIfPresent(String.self, forKey: .type),
           let decoded = PromptParamType(rawValue: rawType) {
            type = decoded
        } else {
            type = .text
        }
        options = try container.decodeIfPresent([String].self, forKey: .options) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
        try container.encode(type.rawValue, forKey: .type)
        if options.isEmpty == false {
            try container.encode(options, forKey: .options)
        }
    }
}

@Model
final class PromptRevision {
    @Attribute(.unique) var uuid: String
    var createdAt: Date
    var author: String
    var titleSnapshot: String
    var bodySnapshot: String
    var tagsSnapshot: [String]
    private var paramsData: Data
    var isMilestone: Bool
    @Relationship(inverse: \PromptItem.revisions)
    var prompt: PromptItem?

    init(
        uuid: String = UUID().uuidString,
        createdAt: Date = Date(),
        author: String = "Local",
        titleSnapshot: String,
        bodySnapshot: String,
        tagsSnapshot: [String],
        paramSnapshots: [RevisionParamSnapshot],
        isMilestone: Bool = false,
        prompt: PromptItem? = nil
    ) {
        self.uuid = uuid
        self.createdAt = createdAt
        self.author = author
        self.titleSnapshot = titleSnapshot
        self.bodySnapshot = bodySnapshot
        self.tagsSnapshot = tagsSnapshot
        self.paramsData = Self.encode(paramSnapshots)
        self.isMilestone = isMilestone
        self.prompt = prompt
    }

    var paramSnapshots: [RevisionParamSnapshot] {
        get { Self.decode(paramsData) }
        set { paramsData = Self.encode(newValue) }
    }

    private static func encode(_ snapshots: [RevisionParamSnapshot]) -> Data {
        do {
            return try JSONEncoder().encode(snapshots)
        } catch {
            assertionFailure("Failed to encode revision param snapshots: \(error)")
            return Data()
        }
    }

    private static func decode(_ data: Data) -> [RevisionParamSnapshot] {
        guard data.isEmpty == false else { return [] }
        do {
            return try JSONDecoder().decode([RevisionParamSnapshot].self, from: data)
        } catch {
            assertionFailure("Failed to decode revision param snapshots: \(error)")
            return []
        }
    }
}

@Model
final class ParamKV {
    var key: String
    var value: String
    var defaultValue: String?
    @Attribute private var typeRawValue: String?
    @Attribute private var optionsStorage: [String] = []
    @Relationship(inverse: \PromptItem.params)
    var owner: PromptItem?

    init(
        key: String,
        value: String,
        defaultValue: String? = nil,
        type: PromptParamType = .text,
        options: [String] = [],
        owner: PromptItem? = nil
    ) {
        self.key = key
        self.value = value
        self.defaultValue = defaultValue
        self.typeRawValue = type.rawValue
        self.optionsStorage = ParamKV.normalizeOptions(options, for: type)
        self.owner = owner
        sanitizeConfigurationForCurrentType()
    }

    var type: PromptParamType {
        get {
            if let stored = typeRawValue, let decoded = PromptParamType(rawValue: stored) {
                return decoded
            }
            if optionsStorage.isEmpty == false {
                return .enumeration
            }
            return .text
        }
        set {
            typeRawValue = newValue.rawValue
            sanitizeConfigurationForCurrentType()
        }
    }

    var options: [String] {
        get { ParamKV.normalizeOptions(optionsStorage, for: type) }
        set {
            optionsStorage = ParamKV.normalizeOptions(newValue, for: type)
            sanitizeConfigurationForCurrentType()
        }
    }

    var resolvedValue: String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case .text:
            if trimmedValue.isEmpty {
                return defaultValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            return value
        case .enumeration:
            let normalizedOptions = Set(options)
            if trimmedValue.isEmpty {
                guard let fallback = defaultValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                      fallback.isEmpty == false,
                      normalizedOptions.contains(fallback) else {
                    return ""
                }
                return fallback
            }

            if normalizedOptions.contains(trimmedValue) {
                return trimmedValue
            }

            guard let fallback = defaultValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  fallback.isEmpty == false,
                  normalizedOptions.contains(fallback) else {
                return ""
            }
            return fallback
        case .toggle:
            let normalized = ParamKV.normalizeOptions(optionsStorage, for: .toggle)
            let onText = normalized.first ?? ""
            let offText = normalized.count > 1 ? normalized[1] : ""
            let trimmedDefault = defaultValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if trimmedValue == onText || trimmedValue == offText {
                return trimmedValue
            }

            if trimmedValue.isEmpty {
                if trimmedDefault == onText || trimmedDefault == offText {
                    return trimmedDefault
                }
                return offText
            }

            if trimmedDefault == onText || trimmedDefault == offText {
                return trimmedDefault
            }

            return offText
        }
    }

    var isEffectivelyEmpty: Bool {
        resolvedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalizeOptions(_ options: [String], for type: PromptParamType) -> [String] {
        switch type {
        case .text:
            return []
        case .enumeration:
            var seen = Set<String>()
            var normalized: [String] = []
            for option in options {
                let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { continue }
                if seen.insert(trimmed).inserted {
                    normalized.append(trimmed)
                }
            }
            return normalized
        case .toggle:
            return normalizeToggleOptions(options)
        }
    }

    private static func normalizeToggleOptions(_ options: [String]) -> [String] {
        let trimmed = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let onText = trimmed.first ?? ""
        let offText = trimmed.count > 1 ? trimmed[1] : ""
        return [onText, offText]
    }

    private func sanitizeConfigurationForCurrentType() {
        optionsStorage = ParamKV.normalizeOptions(optionsStorage, for: type)
        switch type {
        case .text:
            optionsStorage = []
        case .enumeration:
            sanitizeEnumerationValues()
        case .toggle:
            sanitizeToggleValues()
        }
    }

    private func sanitizeEnumerationValues() {
        let normalized = options
        if let defaultValue,
           normalized.contains(defaultValue) == false {
            self.defaultValue = nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty == false,
           normalized.contains(trimmedValue) == false {
            value = ""
        }
    }

    private func sanitizeToggleValues() {
        let normalized = ParamKV.normalizeOptions(optionsStorage, for: .toggle)
        let onText = normalized.first ?? ""
        let offText = normalized.count > 1 ? normalized[1] : ""

        if let currentDefault = defaultValue,
           currentDefault != onText,
           currentDefault != offText {
            defaultValue = offText
        }

        if defaultValue == nil {
            defaultValue = offText
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue != onText && trimmedValue != offText {
            value = offText
        }
    }
}

extension ParamKV {
    var toggleContents: (on: String, off: String) {
        let normalized = ParamKV.normalizeOptions(optionsStorage, for: .toggle)
        let onText = normalized.first ?? ""
        let offText = normalized.count > 1 ? normalized[1] : ""
        return (onText, offText)
    }

    func toggleValue(for state: Bool) -> String {
        let contents = toggleContents
        return state ? contents.on : contents.off
    }

    func toggleState(for value: String) -> Bool? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let contents = toggleContents
        if trimmed == contents.off {
            return false
        }
        if trimmed == contents.on {
            return true
        }
        return nil
    }

    var toggleDefaultState: Bool? {
        if let defaultValue {
            return toggleState(for: defaultValue)
        }
        return toggleState(for: toggleContents.off)
    }
}

@Model
final class PromptItem {
    enum Kind: String, Codable, CaseIterable {
        case standard
        case agentContext
    }

    @Attribute(.unique) var uuid: String
    var title: String
    var body: String
    var pinned: Bool
    var tags: [String] {
        didSet {
            let normalized = PromptTagPolicy.normalize(tags, for: kind)
            if normalized != tags {
                tags = normalized
            }
        }
    }
    var createdAt: Date
    var updatedAt: Date
    @Attribute(originalName: "kind")
    private var kindRawValue: String?
    @Relationship(deleteRule: .cascade)
    var params: [ParamKV]
    @Relationship(deleteRule: .cascade)
    var revisions: [PromptRevision]
    @Relationship(deleteRule: .cascade)
    var attachments: [PromptFileAttachment]

    init(
        uuid: String = UUID().uuidString,
        title: String,
        body: String,
        pinned: Bool = false,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        params: [ParamKV] = [],
        revisions: [PromptRevision] = [],
        attachments: [PromptFileAttachment] = [],
        kind: Kind = .standard
    ) {
        self.uuid = uuid
        self.title = title
        self.body = body
        self.pinned = pinned
        self.tags = PromptTagPolicy.normalize(tags, for: kind)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.kindRawValue = kind.rawValue
        self.params = []
        self.revisions = []
        self.attachments = []

        params.forEach { param in
            param.owner = self
        }
        revisions.forEach { revision in
            revision.prompt = self
        }
        attachments.forEach { attachment in
            attachment.prompt = self
        }
    }

    var kind: Kind {
        get {
            if let rawValue = kindRawValue, let stored = Kind(rawValue: rawValue) {
                return stored
            }
            return .standard
        }
        set {
            kindRawValue = newValue.rawValue
            tags = PromptTagPolicy.normalize(tags, for: newValue)
        }
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}

@Model
final class PromptFileAttachment {
    @Attribute(.unique) var uuid: String
    var displayName: String
    var bookmarkData: Data
    var orderHint: Int
    var lastSyncedAt: Date?
    var lastOverwrittenAt: Date?
    var lastErrorMessage: String?
    @Relationship(inverse: \PromptItem.attachments)
    var prompt: PromptItem?

    init(
        uuid: String = UUID().uuidString,
        displayName: String,
        bookmarkData: Data,
        orderHint: Int,
        lastSyncedAt: Date? = nil,
        lastOverwrittenAt: Date? = nil,
        lastErrorMessage: String? = nil,
        prompt: PromptItem? = nil
    ) {
        self.uuid = uuid
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.orderHint = orderHint
        self.lastSyncedAt = lastSyncedAt
        self.lastOverwrittenAt = lastOverwrittenAt
        self.lastErrorMessage = lastErrorMessage
        self.prompt = prompt
    }

    var url: URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                return nil
            }
            return url
        } catch {
            return nil
        }
    }
}
