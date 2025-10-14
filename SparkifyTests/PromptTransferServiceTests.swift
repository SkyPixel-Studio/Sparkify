import Foundation
import XCTest
import SwiftData
@testable import Sparkify

@MainActor
final class PromptTransferServiceTests: XCTestCase {

    func testExportAndImportRoundTripPersistsAllFields() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext

        let prompt = PromptItem(
            uuid: "prompt-1",
            title: "Greetings",
            body: "Hello {name}",
            pinned: true,
            tags: ["welcome", "demo"],
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            params: [
                ParamKV(key: "name", value: "Leader")
            ],
            kind: .agentContext
        )
        sourceContext.insert(prompt)
        try sourceContext.save()

        let data = try PromptTransferService.exportData(from: [prompt])
        let payloadString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(payloadString)

        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let prompts = jsonObject?["prompts"] as? [[String: Any]]
        XCTAssertEqual(prompts?.first?["kind"] as? String, "agentContext")

        let destinationContainer = try makeInMemoryContainer()
        let destinationContext = destinationContainer.mainContext
        let summary = try PromptTransferService.importData(data, into: destinationContext)

        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(summary.updated, 0)

        let fetched = try destinationContext.fetch(FetchDescriptor<PromptItem>()).first
        XCTAssertEqual(fetched?.uuid, "prompt-1")
        XCTAssertEqual(fetched?.title, "Greetings")
        XCTAssertEqual(fetched?.body, "Hello {name}")
        XCTAssertEqual(fetched?.pinned, true)
        XCTAssertEqual(fetched?.tags, [PromptTagPolicy.agentContextDisplayTag, "welcome", "demo"])
        XCTAssertEqual(fetched?.params.first?.key, "name")
        XCTAssertEqual(fetched?.params.first?.value, "Leader")
        XCTAssertEqual(fetched?.params.first?.defaultValue, "Leader")
        XCTAssertEqual(fetched?.createdAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(fetched?.updatedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(fetched?.kind, .agentContext)
    }

    func testImportMergesByUUID() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let original = PromptItem(
            uuid: "prompt-merge",
            title: "Old",
            body: "Ping {name}",
            pinned: false,
            tags: ["legacy"],
            params: [
                ParamKV(key: "name", value: "Original")
            ]
        )
        context.insert(original)
        try context.save()

        let updatedPrompt = PromptItem(
            uuid: "prompt-merge",
            title: "New Title",
            body: "Hello {name} from {company}",
            pinned: true,
            tags: ["modern", "eng"],
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            params: [
                ParamKV(key: "name", value: "Leader"),
                ParamKV(key: "company", value: "Apple Pie Logistics")
            ],
            kind: .standard
        )
        XCTAssertEqual(updatedPrompt.params.count, 2)

        let data = try PromptTransferService.exportData(from: [updatedPrompt])
        let summary = try PromptTransferService.importData(data, into: context)

        XCTAssertEqual(summary.inserted, 0)
        XCTAssertEqual(summary.updated, 1)

        let fetched = try context.fetch(FetchDescriptor<PromptItem>()).first
        XCTAssertEqual(fetched?.title, "New Title")
        XCTAssertEqual(fetched?.body, "Hello {name} from {company}")
        XCTAssertEqual(fetched?.pinned, true)
        XCTAssertEqual(fetched?.tags, ["modern", "eng"])
        XCTAssertEqual(fetched?.params.map(\.key), ["name", "company"])
        XCTAssertEqual(fetched?.params.count, 2)
        let params = fetched?.params ?? []
        XCTAssertEqual(params.first(where: { $0.key == "name" })?.defaultValue, "Leader")
        XCTAssertEqual(params.first(where: { $0.key == "company" })?.defaultValue, "Apple Pie Logistics")
        XCTAssertEqual(fetched?.kind, .standard)

        // Ensure existing attachments stay untouched when kind remains standard
        XCTAssertEqual(fetched?.attachments.count, 0)
    }

    func testImportDefaultsKindWhenMissing() throws {
        let legacyJSON = """
        {
            "version": 1,
            "exportedAt": "2024-01-01T00:00:00Z",
            "prompts": [
                {
                    "uuid": "legacy-1",
                    "title": "Legacy",
                    "body": "",
                    "pinned": false,
                    "tags": [],
                    "createdAt": "2024-01-01T00:00:00Z",
                    "updatedAt": "2024-01-01T00:00:00Z",
                    "params": []
                }
            ]
        }
        """.data(using: .utf8)!

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let summary = try PromptTransferService.importData(legacyJSON, into: context)
        XCTAssertEqual(summary.inserted, 1)

        let fetched = try context.fetch(FetchDescriptor<PromptItem>()).first
        XCTAssertEqual(fetched?.uuid, "legacy-1")
        XCTAssertEqual(fetched?.kind, .standard)
    }

    func testImportRejectsUnsupportedVersion() throws {
        let json = """
        {
            "version": 2,
            "exportedAt": "2024-01-01T00:00:00Z",
            "prompts": []
        }
        """.data(using: .utf8)!

        let container = try makeInMemoryContainer()

        XCTAssertThrowsError(try PromptTransferService.importData(json, into: container.mainContext)) { error in
            guard case PromptTransferError.unsupportedVersion(2) = error else {
                return XCTFail("Expected unsupportedVersion error, got \\(error)")
            }
        }
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
