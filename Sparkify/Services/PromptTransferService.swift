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

        guard package.version <= currentVersion else {
            throw PromptTransferError.unsupportedVersion(package.version)
        }

        var inserted = 0
        var updated = 0

        for payload in package.prompts {
            if let existing = try fetchPrompt(uuid: payload.uuid, in: context) {
                apply(payload: payload, to: existing, in: context)
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

    private static func apply(payload: PromptPayload, to prompt: PromptItem, in context: ModelContext) {
        prompt.title = payload.title
        prompt.body = payload.body
        prompt.pinned = payload.pinned
        prompt.kind = payload.kind
        prompt.tags = PromptTagPolicy.normalize(payload.tags, for: prompt.kind)
        prompt.createdAt = payload.createdAt
        prompt.updatedAt = payload.updatedAt

        var existingParamsByKey: [String: ParamKV] = [:]
        var dedupedExisting: [ParamKV] = []
        for param in prompt.params {
            if existingParamsByKey[param.key] == nil {
                existingParamsByKey[param.key] = param
                dedupedExisting.append(param)
            } else {
                context.delete(param)
            }
        }
        prompt.params = dedupedExisting

        var updatedParams: [ParamKV] = []
        updatedParams.reserveCapacity(payload.params.count)

        for paramPayload in payload.params {
            let param = existingParamsByKey.removeValue(forKey: paramPayload.key) ?? ParamKV(
                key: paramPayload.key,
                value: paramPayload.value,
                defaultValue: paramPayload.defaultValue,
                type: paramPayload.type,
                options: paramPayload.options
            )
            param.type = paramPayload.type
            param.options = paramPayload.options
            param.value = sanitizedValue(paramPayload.value, for: paramPayload.type, options: paramPayload.options)
            param.defaultValue = sanitizedDefault(paramPayload.defaultValue, for: paramPayload.type, options: paramPayload.options)
            if param.owner !== prompt {
                param.owner = prompt
            }
            updatedParams.append(param)
        }

        for leftover in existingParamsByKey.values {
            if let index = prompt.params.firstIndex(where: { $0 === leftover }) {
                prompt.params.remove(at: index)
            }
            context.delete(leftover)
        }

        prompt.params = updatedParams
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
                ParamKV(
                    key: $0.key,
                    value: sanitizedValue($0.value, for: $0.type, options: $0.options),
                    defaultValue: sanitizedDefault($0.defaultValue, for: $0.type, options: $0.options),
                    type: $0.type,
                    options: $0.options
                )
            },
            attachments: [],
            kind: payload.kind
        )
    }

    private static func sanitizedValue(_ raw: String, for type: PromptParamType, options: [String]) -> String {
        guard type == .enumeration else { return raw }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, options.contains(trimmed) else { return "" }
        return trimmed
    }

    private static func sanitizedDefault(_ raw: String?, for type: PromptParamType, options: [String]) -> String? {
        guard let raw, raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type == .enumeration else { return trimmed }
        return options.contains(trimmed) ? trimmed : nil
    }

    private static let currentVersion = 2
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
                defaultValue: $0.defaultValue ?? $0.value,
                type: $0.type,
                options: $0.options
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
    let type: PromptParamType
    let options: [String]

    init(key: String, value: String, defaultValue: String?, type: PromptParamType, options: [String]) {
        self.key = key
        self.value = value
        self.type = type
        self.options = ParamPayload.normalize(options)
        if let defaultValue,
           defaultValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let trimmed = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if type == .enumeration, self.options.contains(trimmed) == false {
                self.defaultValue = nil
            } else {
                self.defaultValue = trimmed
            }
        } else {
            self.defaultValue = nil
        }
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
        let decodedOptions = try container.decodeIfPresent([String].self, forKey: .options) ?? []
        options = ParamPayload.normalize(decodedOptions)
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

    private static func normalize(_ options: [String]) -> [String] {
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

enum PromptTransferError: LocalizedError {
    case invalidFormat(underlying: Error)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return String(localized: "import_failure_reason_invalid_format", defaultValue: "JSON 格式无法识别，请确认文件是否由 Sparkify 导出。")
        case .unsupportedVersion(let version):
            return String(format: String(localized: "import_failure_reason_unsupported_version", defaultValue: "暂不支持导入来自版本 %d 的导出文件，请更新 Sparkify。"), version)
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
