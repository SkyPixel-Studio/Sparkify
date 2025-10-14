import Foundation
import SwiftData

struct RevisionParamSnapshot: Codable, Equatable {
    let key: String
    let value: String
    let defaultValue: String?
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
    @Relationship(inverse: \PromptItem.params)
    var owner: PromptItem?

    init(key: String, value: String, defaultValue: String? = nil, owner: PromptItem? = nil) {
        self.key = key
        self.value = value
        self.defaultValue = defaultValue
        self.owner = owner
    }

    var resolvedValue: String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            return defaultValue ?? ""
        }
        return value
    }

    var isEffectivelyEmpty: Bool {
        resolvedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
