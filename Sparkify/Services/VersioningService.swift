import Foundation
import SwiftData

enum VersioningService {
    private static let defaultRetentionLimit = 50

    struct PromptSnapshot: Equatable {
        var title: String
        var body: String
        var tags: [String]
        var params: [RevisionParamSnapshot]

        init(title: String, body: String, tags: [String], params: [RevisionParamSnapshot]) {
            self.title = title
            self.body = body
            self.tags = tags
            self.params = params
        }

        init(from prompt: PromptItem) {
            self.init(
                title: prompt.title,
                body: prompt.body,
                tags: prompt.tags,
                params: prompt.params.map {
                    RevisionParamSnapshot(
                        key: $0.key,
                        value: $0.value,
                        defaultValue: $0.defaultValue
                    )
                }
            )
        }

        init(from revision: PromptRevision) {
            self.init(
                title: revision.titleSnapshot,
                body: revision.bodySnapshot,
                tags: revision.tagsSnapshot,
                params: revision.paramSnapshots
            )
        }
    }

    struct TextDiffSegment: Identifiable, Equatable {
        enum Kind {
            case added
            case removed
            case unchanged
        }

        let id = UUID()
        let kind: Kind
        let text: String
    }

    struct TagDiff {
        var added: [String]
        var removed: [String]
        var unchanged: [String]
    }

    struct ParameterDiff: Identifiable {
        enum ChangeKind {
            case added
            case removed
            case modified
            case unchanged
        }

        let id = UUID()
        let key: String
        let change: ChangeKind
        let valueSegments: [TextDiffSegment]
        let defaultValueSegments: [TextDiffSegment]
    }

    struct PromptDiff {
        var titleSegments: [TextDiffSegment]
        var bodySegments: [TextDiffSegment]
        var tagDiff: TagDiff
        var parameterDiffs: [ParameterDiff]
    }

    static func ensureBaselineRevision(for prompt: PromptItem, in context: ModelContext, author: String? = nil) {
        guard prompt.revisions.isEmpty else { return }
        let snapshot = PromptSnapshot(from: prompt)
        let effectiveAuthor = author ?? PreferencesService.shared.userSignature
        let revision = makeRevision(from: snapshot, author: effectiveAuthor, isMilestone: true)
        revision.prompt = prompt
        context.insert(revision)
        prompt.revisions.append(revision)
    }

    @discardableResult
    static func captureRevision(
        for prompt: PromptItem,
        in context: ModelContext,
        author: String? = nil,
        isMilestone: Bool = false,
        retentionLimit: Int = defaultRetentionLimit
    ) -> PromptRevision? {
        let snapshot = PromptSnapshot(from: prompt)
        if let latest = latestRevision(for: prompt), snapshot == PromptSnapshot(from: latest) {
            return nil
        }

        let effectiveAuthor = author ?? PreferencesService.shared.userSignature
        let revision = makeRevision(from: snapshot, author: effectiveAuthor, isMilestone: isMilestone)
        revision.prompt = prompt
        context.insert(revision)
        prompt.revisions.append(revision)

        pruneRevisionsIfNeeded(for: prompt, in: context, retentionLimit: retentionLimit)
        prompt.revisions.sort { $0.createdAt > $1.createdAt }
        return revision
    }

    static func revisions(for prompt: PromptItem, limit: Int? = nil) -> [PromptRevision] {
        let sorted = prompt.revisions.sorted { $0.createdAt > $1.createdAt }
        guard let limit else { return sorted }
        return Array(sorted.prefix(limit))
    }

    static func diff(from older: PromptRevision, to newer: PromptRevision) -> PromptDiff {
        diff(from: PromptSnapshot(from: older), to: PromptSnapshot(from: newer))
    }

    static func diff(from olderSnapshot: PromptSnapshot, to newerSnapshot: PromptSnapshot) -> PromptDiff {
        PromptDiff(
            titleSegments: textDiffSegments(from: olderSnapshot.title, to: newerSnapshot.title),
            bodySegments: textDiffSegments(from: olderSnapshot.body, to: newerSnapshot.body),
            tagDiff: tagDiff(from: olderSnapshot.tags, to: newerSnapshot.tags),
            parameterDiffs: parameterDiffs(from: olderSnapshot.params, to: newerSnapshot.params)
        )
    }

    static func diffBetweenLatestRevisionAndCurrentPrompt(_ prompt: PromptItem) -> PromptDiff? {
        guard let latest = latestRevision(for: prompt) else { return nil }
        return diff(from: latest, to: makeRevision(from: PromptSnapshot(from: prompt), author: "Current", isMilestone: false))
    }

    private static func makeRevision(from snapshot: PromptSnapshot, author: String, isMilestone: Bool) -> PromptRevision {
        PromptRevision(
            author: author,
            titleSnapshot: snapshot.title,
            bodySnapshot: snapshot.body,
            tagsSnapshot: snapshot.tags,
            paramSnapshots: snapshot.params,
            isMilestone: isMilestone
        )
    }

    private static func latestRevision(for prompt: PromptItem) -> PromptRevision? {
        prompt.revisions.max(by: { $0.createdAt < $1.createdAt })
    }

    private static func pruneRevisionsIfNeeded(for prompt: PromptItem, in context: ModelContext, retentionLimit: Int) {
        guard retentionLimit > 0 else { return }
        let sorted = prompt.revisions.sorted { $0.createdAt > $1.createdAt }
        let nonMilestones = sorted.filter { $0.isMilestone == false }
        guard nonMilestones.count > retentionLimit else { return }
        let survivors = Set(nonMilestones.prefix(retentionLimit).map(\.uuid))
        for revision in nonMilestones.dropFirst(retentionLimit) {
            if survivors.contains(revision.uuid) == false {
                context.delete(revision)
            }
        }
    }

    private static func textDiffSegments(from older: String, to newer: String) -> [TextDiffSegment] {
        let oldTokens = tokenize(older)
        let newTokens = tokenize(newer)
        var matrix = Array(repeating: Array(repeating: 0, count: newTokens.count + 1), count: oldTokens.count + 1)

        for i in 0..<oldTokens.count {
            for j in 0..<newTokens.count {
                if oldTokens[i] == newTokens[j] {
                    matrix[i + 1][j + 1] = matrix[i][j] + 1
                } else {
                    matrix[i + 1][j + 1] = max(matrix[i][j + 1], matrix[i + 1][j])
                }
            }
        }

        var i = oldTokens.count
        var j = newTokens.count
        var reversedSegments: [TextDiffSegment] = []

        while i > 0 || j > 0 {
            if i > 0, j > 0, oldTokens[i - 1] == newTokens[j - 1] {
                reversedSegments.append(TextDiffSegment(kind: .unchanged, text: oldTokens[i - 1]))
                i -= 1
                j -= 1
            } else if j > 0, (i == 0 || matrix[i][j - 1] >= matrix[i - 1][j]) {
                reversedSegments.append(TextDiffSegment(kind: .added, text: newTokens[j - 1]))
                j -= 1
            } else if i > 0 {
                reversedSegments.append(TextDiffSegment(kind: .removed, text: oldTokens[i - 1]))
                i -= 1
            }
        }

        let ordered = Array(reversedSegments.reversed())
        return mergeAdjacentSegments(in: ordered)
    }

    private static func mergeAdjacentSegments(in segments: [TextDiffSegment]) -> [TextDiffSegment] {
        guard segments.isEmpty == false else { return [] }
        var merged: [TextDiffSegment] = []

        for segment in segments {
            if let lastIndex = merged.indices.last, merged[lastIndex].kind == segment.kind {
                let combined = TextDiffSegment(kind: merged[lastIndex].kind, text: merged[lastIndex].text + segment.text)
                merged[lastIndex] = combined
            } else {
                merged.append(segment)
            }
        }
        return merged
    }

    private static func tokenize(_ text: String) -> [String] {
        guard text.isEmpty == false else { return [] }
        var tokens: [String] = []
        var current = ""
        var currentIsWhitespace: Bool?

        for character in text {
            let isWhitespace = character.isWhitespace
            if let flag = currentIsWhitespace, flag == isWhitespace {
                current.append(character)
            } else {
                if current.isEmpty == false {
                    tokens.append(current)
                }
                current = String(character)
                currentIsWhitespace = isWhitespace
            }
        }

        if current.isEmpty == false {
            tokens.append(current)
        }
        return tokens
    }

    private static func tagDiff(from older: [String], to newer: [String]) -> TagDiff {
        let oldSet = Set(older.map { $0.lowercased() })
        let newSet = Set(newer.map { $0.lowercased() })
        let addedRaw = newSet.subtracting(oldSet)
        let removedRaw = oldSet.subtracting(newSet)

        let added = newer.filter { addedRaw.contains($0.lowercased()) }
        let removed = older.filter { removedRaw.contains($0.lowercased()) }
        let unchanged = newer.filter { newSet.contains($0.lowercased()) && oldSet.contains($0.lowercased()) }
        return TagDiff(added: added, removed: removed, unchanged: unchanged)
    }

    private static func parameterDiffs(
        from older: [RevisionParamSnapshot],
        to newer: [RevisionParamSnapshot]
    ) -> [ParameterDiff] {
        let oldDictionary = Dictionary(uniqueKeysWithValues: older.map { ($0.key, $0) })
        let newDictionary = Dictionary(uniqueKeysWithValues: newer.map { ($0.key, $0) })
        let allKeys = Set(oldDictionary.keys).union(newDictionary.keys)
        let sortedKeys = allKeys.sorted()

        return sortedKeys.compactMap { key in
            let oldValue = oldDictionary[key]
            let newValue = newDictionary[key]

            switch (oldValue, newValue) {
            case (nil, nil):
                return nil
            case (nil, let newValue?):
                return ParameterDiff(
                    key: key,
                    change: .added,
                    valueSegments: textDiffSegments(from: "", to: newValue.value),
                    defaultValueSegments: textDiffSegments(from: "", to: newValue.defaultValue ?? "")
                )
            case (let oldValue?, nil):
                return ParameterDiff(
                    key: key,
                    change: .removed,
                    valueSegments: textDiffSegments(from: oldValue.value, to: ""),
                    defaultValueSegments: textDiffSegments(from: oldValue.defaultValue ?? "", to: "")
                )
            case (let oldValue?, let newValue?):
                let valueSegments = textDiffSegments(from: oldValue.value, to: newValue.value)
                let defaultDiff = textDiffSegments(from: oldValue.defaultValue ?? "", to: newValue.defaultValue ?? "")
                let unchanged = oldValue.value == newValue.value && (oldValue.defaultValue ?? "") == (newValue.defaultValue ?? "")
                let change: ParameterDiff.ChangeKind = unchanged ? .unchanged : .modified
                return ParameterDiff(
                    key: key,
                    change: change,
                    valueSegments: valueSegments,
                    defaultValueSegments: defaultDiff
                )
            }
        }
    }
}
