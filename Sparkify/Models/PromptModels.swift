import Foundation
import SwiftData

enum PromptParamType: String, Codable, CaseIterable {
    case text
    case enumeration
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
        self.optionsStorage = ParamKV.normalizeOptions(options)
        self.owner = owner
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
            if newValue != .enumeration {
                optionsStorage = []
            }
        }
    }

    var options: [String] {
        get { optionsStorage }
        set { optionsStorage = ParamKV.normalizeOptions(newValue) }
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
        }
    }

    var isEffectivelyEmpty: Bool {
        resolvedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalizeOptions(_ options: [String]) -> [String] {
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
