import XCTest
@testable import Sparkify

final class AgentContextFileServiceTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentContextFileServiceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testMakeAttachmentsPreservesOrderAndMetadata() throws {
        let fileA = tempDirectory.appendingPathComponent("alpha.md")
        try "A".write(to: fileA, atomically: true, encoding: .utf8)
        let fileB = tempDirectory.appendingPathComponent("beta.md")
        try "B".write(to: fileB, atomically: true, encoding: .utf8)

        let attachments = try AgentContextFileService.shared.makeAttachments(from: [fileA, fileB], startingOrder: 3)

        XCTAssertEqual(attachments.count, 2)
        XCTAssertEqual(attachments[0].displayName, "alpha.md")
        XCTAssertEqual(attachments[1].displayName, "beta.md")
        XCTAssertEqual(attachments[0].orderHint, 3)
        XCTAssertEqual(attachments[1].orderHint, 4)
    }

    func testPullAndOverwriteRoundTripUpdatesTimestamps() throws {
        let file = tempDirectory.appendingPathComponent("context.md")
        try "Original body".write(to: file, atomically: true, encoding: .utf8)

        let attachments = try AgentContextFileService.shared.makeAttachments(from: [file])
        let prompt = PromptItem(title: "Agent", body: "", attachments: attachments, kind: .agentContext)

        guard let attachment = prompt.attachments.first else {
            return XCTFail("Attachment should exist")
        }

        let pullResult = AgentContextFileService.shared.pullContent(from: attachment)
        XCTAssertTrue(pullResult.isSuccess)
        XCTAssertEqual(pullResult.content, "Original body")
        XCTAssertNotNil(attachment.lastSyncedAt)

        prompt.body = "Updated body"
        let pushResults = AgentContextFileService.shared.overwrite(prompt.body, to: [attachment])
        XCTAssertEqual(pushResults.count, 1)
        XCTAssertTrue(pushResults[0].isSuccess)
        XCTAssertNotNil(attachment.lastOverwrittenAt)

        let diskContent = try String(contentsOf: file)
        XCTAssertEqual(diskContent, "Updated body")
    }
}
