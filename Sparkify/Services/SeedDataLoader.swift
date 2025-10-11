import Foundation
import SwiftData

struct SeedDataLoader {
    static func ensureSeedData(using context: ModelContext) throws {
        var descriptor = FetchDescriptor<PromptItem>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first, existing.uuid.isEmpty == false {
            return
        }

        let seeds = defaultItems()
        for item in seeds {
            context.insert(item)
        }
        try context.save()
    }

    private static func defaultItems() -> [PromptItem] {
        [
            PromptItem(
                title: "Cold Email Outreach",
                body: "Hi {name}, I’m {sender} from {company}. I noticed {observation}. Would you be open to a quick {duration} call this week?",
                tags: ["outreach", "sales"],
                params: [
                    ParamKV(key: "name", value: ""),
                    ParamKV(key: "sender", value: ""),
                    ParamKV(key: "company", value: "Apple Pie Logistics"),
                    ParamKV(key: "observation", value: "your recent product launch"),
                    ParamKV(key: "duration", value: "15-minute")
                ]
            ),
            PromptItem(
                title: "Bug Report Template",
                body: "Summary:\n- Issue: {issue}\n- Expected: {expected}\n- Actual: {actual}\n- Steps: {steps}\n\nLogs:\n{logs}",
                tags: ["engineering", "qa"],
                params: [
                    ParamKV(key: "issue", value: ""),
                    ParamKV(key: "expected", value: ""),
                    ParamKV(key: "actual", value: ""),
                    ParamKV(key: "steps", value: "1. ..."),
                    ParamKV(key: "logs", value: "Attach console output here")
                ]
            ),
            PromptItem(
                title: "Summarize Meeting",
                body: "Meeting with {partner} on {date}. Key topics: {topics}. Decisions: {decisions}. Next steps: {next_steps}.",
                tags: ["summary"],
                params: [
                    ParamKV(key: "partner", value: ""),
                    ParamKV(key: "date", value: ""),
                    ParamKV(key: "topics", value: ""),
                    ParamKV(key: "decisions", value: ""),
                    ParamKV(key: "next_steps", value: "")
                ]
            )
        ]
    }
}
