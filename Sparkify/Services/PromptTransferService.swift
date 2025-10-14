import Foundation
import SwiftData

struct PromptTransferService {
    struct Summary {
        let inserted: Int
        let updated: Int
    }

    static func exportData(from prompts: [PromptItem]) throws -> Data {
        let package = ExportPackage(
            version: currentVersion,
            exportedAt: Date(),
            prompts: prompts.map(PromptPayload.init(from:))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    static func importData(_ data: Data, into context: ModelContext) throws -> Summary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package: ExportPackage
        do {
            package = try decoder.decode(ExportPackage.self, from: data)
        } catch {
            throw PromptTransferError.invalidFormat(underlying: error)
        }

        guard package.version == currentVersion else {
            throw PromptTransferError.unsupportedVersion(package.version)
        }

        var inserted = 0
        var updated = 0

        for payload in package.prompts {
            if let existing = try fetchPrompt(uuid: payload.uuid, in: context) {
                apply(payload: payload, to: existing)
                VersioningService.captureRevision(
                    for: existing,
                    in: context,
                    author: "Import",
                    isMilestone: true
                )
                updated += 1
            } else {
                let created = makePrompt(from: payload)
                context.insert(created)
                VersioningService.ensureBaselineRevision(for: created, in: context, author: "Import")
                inserted += 1
            }
        }

        if context.hasChanges {
            try context.save()
        }

        return Summary(inserted: inserted, updated: updated)
    }

    private static func fetchPrompt(uuid: String, in context: ModelContext) throws -> PromptItem? {
        var descriptor = FetchDescriptor<PromptItem>(
            predicate: #Predicate { $0.uuid == uuid }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func apply(payload: PromptPayload, to prompt: PromptItem) {
        prompt.title = payload.title
        prompt.body = payload.body
        prompt.pinned = payload.pinned
        prompt.kind = payload.kind
        prompt.tags = PromptTagPolicy.normalize(payload.tags, for: prompt.kind)
        prompt.createdAt = payload.createdAt
        prompt.updatedAt = payload.updatedAt
        prompt.params = payload.params.map { param in
            ParamKV(
                key: param.key,
                value: param.value,
                defaultValue: param.defaultValue,
                owner: prompt
            )
        }
    }

    private static func makePrompt(from payload: PromptPayload) -> PromptItem {
        PromptItem(
            uuid: payload.uuid,
            title: payload.title,
            body: payload.body,
            pinned: payload.pinned,
            tags: payload.tags,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt,
            params: payload.params.map {
                ParamKV(key: $0.key, value: $0.value, defaultValue: $0.defaultValue)
            },
            attachments: [],
            kind: payload.kind
        )
    }

    private static let currentVersion = 1
}

// MARK: - Codable structures

private struct ExportPackage: Codable {
    let version: Int
    let exportedAt: Date
    let prompts: [PromptPayload]
}

private struct PromptPayload: Codable {
    let uuid: String
    let title: String
    let body: String
    let pinned: Bool
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let params: [ParamPayload]
    let kind: PromptItem.Kind

    init(from prompt: PromptItem) {
        uuid = prompt.uuid
        title = prompt.title
        body = prompt.body
        pinned = prompt.pinned
        tags = prompt.tags
        createdAt = prompt.createdAt
        updatedAt = prompt.updatedAt
        params = prompt.params.map {
            ParamPayload(
                key: $0.key,
                value: $0.value,
                defaultValue: $0.defaultValue ?? $0.value
            )
        }
        kind = prompt.kind
    }

    private enum CodingKeys: String, CodingKey {
        case uuid
        case title
        case body
        case pinned
        case tags
        case createdAt
        case updatedAt
        case params
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        pinned = try container.decode(Bool.self, forKey: .pinned)
        tags = try container.decode([String].self, forKey: .tags)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        params = try container.decode([ParamPayload].self, forKey: .params)
        if let kindRawValue = try container.decodeIfPresent(String.self, forKey: .kind),
           let decodedKind = PromptItem.Kind(rawValue: kindRawValue) {
            kind = decodedKind
        } else {
            kind = .standard
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(pinned, forKey: .pinned)
        try container.encode(tags, forKey: .tags)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(params, forKey: .params)
        try container.encode(kind.rawValue, forKey: .kind)
    }
}

private struct ParamPayload: Codable {
    let key: String
    let value: String
    let defaultValue: String?

    init(key: String, value: String, defaultValue: String?) {
        self.key = key
        self.value = value
        if let defaultValue, defaultValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            self.defaultValue = defaultValue
        } else {
            self.defaultValue = nil
        }
    }
}

enum PromptTransferError: LocalizedError {
    case invalidFormat(underlying: Error)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "JSON 格式无法识别，请确认文件是否由 Sparkify 导出。"
        case .unsupportedVersion(let version):
            return "暂不支持导入来自版本 \(version) 的导出文件，请更新 Sparkify。"
        }
    }

    var failureReason: String? {
        switch self {
        case .invalidFormat(let underlying):
            return underlying.localizedDescription
        case .unsupportedVersion:
            return nil
        }
    }
}
