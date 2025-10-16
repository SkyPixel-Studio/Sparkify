import XCTest
import SwiftData
@testable import Sparkify

@MainActor
final class PromptStorageTests: XCTestCase {
    func testSeedDataCreatesThreeRecordsWhenEmpty() throws {
        let seedKey = "com.sparkify.hasSeededDefaultPrompts"
        UserDefaults.standard.removeObject(forKey: seedKey)
        defer { UserDefaults.standard.removeObject(forKey: seedKey) }
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try SeedDataLoader.ensureSeedData(using: context)

        let descriptor = FetchDescriptor<PromptItem>()
        let items = try context.fetch(descriptor)
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { !$0.title.isEmpty })
    }

    func testCreatingPromptPersistsAndUpdatesTimestamp() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let prompt = PromptItem(title: "Test", body: "Hello {name}")
        context.insert(prompt)
        prompt.updateTimestamp()
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PromptItem>()).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Test")
    }

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
