import Foundation
import SwiftData

@Model
final class ParamKV {
    var key: String
    var value: String
    @Relationship(inverse: \PromptItem.params)
    var owner: PromptItem?

    init(key: String, value: String, owner: PromptItem? = nil) {
        self.key = key
        self.value = value
        self.owner = owner
    }
}

@Model
final class PromptItem {
    @Attribute(.unique) var uuid: String
    var title: String
    var body: String
    var pinned: Bool
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade)
    var params: [ParamKV]

    init(
        uuid: String = UUID().uuidString,
        title: String,
        body: String,
        pinned: Bool = false,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        params: [ParamKV] = []
    ) {
        self.uuid = uuid
        self.title = title
        self.body = body
        self.pinned = pinned
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.params = params
        self.params.forEach { $0.owner = self }
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}
