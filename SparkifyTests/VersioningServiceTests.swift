import XCTest
import SwiftData
@testable import Sparkify

@MainActor
final class VersioningServiceTests: XCTestCase {
    func testCaptureRevisionSkipsIdenticalSnapshots() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let prompt = PromptItem(
            title: "Greeting",
            body: "Hello {name}",
            params: [
                ParamKV(key: "name", value: "Leader")
            ]
        )

        context.insert(prompt)
        VersioningService.ensureBaselineRevision(for: prompt, in: context, author: "Test")
        XCTAssertEqual(prompt.revisions.count, 1)

        let noChangeRevision = VersioningService.captureRevision(for: prompt, in: context, author: "Test")
        XCTAssertNil(noChangeRevision)
        XCTAssertEqual(prompt.revisions.count, 1)

        prompt.body = "Hello {name}!"
        let changedRevision = VersioningService.captureRevision(for: prompt, in: context, author: "Test")
        XCTAssertNotNil(changedRevision)
        XCTAssertEqual(prompt.revisions.count, 2)
    }

    func testDiffDetectsTextAndTagChanges() {
        let older = VersioningService.PromptSnapshot(
            title: "Hello",
            body: "Hi there",
            tags: ["alpha"],
            params: [
                RevisionParamSnapshot(key: "name", value: "Exusiai", defaultValue: nil)
            ]
        )

        let newer = VersioningService.PromptSnapshot(
            title: "Hello Leader",
            body: "Hi there boss",
            tags: ["alpha", "beta"],
            params: [
                RevisionParamSnapshot(key: "name", value: "Leader", defaultValue: nil),
                RevisionParamSnapshot(key: "callSign", value: "Angel", defaultValue: "Angel")
            ]
        )

        let diff = VersioningService.diff(from: older, to: newer)

        XCTAssertTrue(diff.titleSegments.contains(where: { $0.kind == .added && $0.text.contains("Leader") }))
        XCTAssertTrue(diff.bodySegments.contains(where: { $0.kind == .added && $0.text.contains("boss") }))
        XCTAssertEqual(diff.tagDiff.added, ["beta"])
        XCTAssertEqual(diff.tagDiff.removed, [])

        let nameDiff = diff.parameterDiffs.first(where: { $0.key == "name" })
        XCTAssertEqual(nameDiff?.change, .modified)
        XCTAssertTrue(nameDiff?.valueSegments.contains(where: { $0.kind == .added && $0.text.contains("Leader") }) ?? false)
        let callSignDiff = diff.parameterDiffs.first(where: { $0.key == "callSign" })
        XCTAssertEqual(callSignDiff?.change, .added)
    }

    // MARK: - Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            PromptItem.self,
            ParamKV.self,
            PromptRevision.self,
            PromptFileAttachment.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
