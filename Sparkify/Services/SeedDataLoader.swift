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
        for item in seeds {
            VersioningService.ensureBaselineRevision(for: item, in: context, author: "Seed")
        }
        try context.save()
    }

    private static func defaultItems() -> [PromptItem] {
        [
            PromptItem(
                title: "一页纸 · 闪电总结（即插即用）",
                body: """
                请阅读以下原始材料，并以{tone}的语气输出一份**中文一页纸总结**。只按下列模板输出 Markdown，勿添加任何额外说明或前言。

                # 标题（≤12字）
                基于材料自动提炼主题与对象

                ## TL;DR（≤60字）
                一句话浓缩结论

                ## 关键要点（最多5条，每条≤24字）
                1. …
                2. …
                3. …
                4. …
                5. …

                ## 数据与证据（最多3项）
                - 名称：数值（时间/来源）
                - 名称：数值（时间/来源）
                - 名称：数值（时间/来源）

                ## 结论与影响（≤2条）
                - …
                - …

                ## 行动清单（≤3条｜格式：动作 — 负责人 — 截止日期 — 优先级）
                - …
                - …
                - …

                ## 未决 / 风险（≤2条）
                - …

                > 规则：
                > - 先事实后判断；拒绝空话与堆砌。
                > - 若材料不足，请在"未决 / 风险"首条提出 1 个最关键澄清问题。
                > - 所有小节均以简明句呈现；无数据时写"未提及"。

                —— 原始材料开始 ——
                {content}
                —— 原始材料结束 ——
                """,
                pinned: true,
                tags: ["示例", "入门", "一页纸", "总结"],
                params: [
                    ParamKV(key: "tone", value: "简洁专业"),
                    ParamKV(key: "content", value: "（在此粘贴要总结的原始内容）")
                ]
            )
        ]
    }
}
