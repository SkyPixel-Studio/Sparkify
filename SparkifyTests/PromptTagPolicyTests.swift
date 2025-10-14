import XCTest
@testable import Sparkify

final class PromptTagPolicyTests: XCTestCase {

    func testNormalizeDeduplicatesCaseInsensitively() {
        let normalized = PromptTagPolicy.normalize(
            ["AI", "ai", "Ai  ", "Data", "data"],
            for: .standard
        )

        XCTAssertEqual(normalized, ["AI", "Data"])
    }

    func testAgentContextKindAlwaysPrependsReservedTag() {
        let normalized = PromptTagPolicy.normalize(
            ["workflow", PromptTagPolicy.agentContextDisplayTag],
            for: .agentContext
        )

        XCTAssertEqual(normalized.first, PromptTagPolicy.agentContextDisplayTag)
        XCTAssertEqual(Array(normalized.dropFirst()), ["workflow"])
    }

    func testRemovingReservedTagsFiltersAgentContextVariants() {
        let filtered = PromptTagPolicy.removingReservedTags(from: [
            PromptTagPolicy.agentContextDisplayTag,
            "Agent Context",
            "agent context",
            "workflow"
        ])

        XCTAssertEqual(filtered, ["workflow"])
    }
}
