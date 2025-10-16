import Foundation
import SwiftData

struct SeedDataLoader {
    /// Key for tracking seed data initialization state
    /// Note: Also exposed via PreferencesService.seedDataKey for reset functionality
    private static let hasSeededKey = "com.sparkify.hasSeededDefaultPrompts"
    
    static func ensureSeedData(using context: ModelContext) throws {
        // 检查 UserDefaults 标记，确保只在真正的初始化时创建种子数据
        if UserDefaults.standard.bool(forKey: hasSeededKey) {
            return
        }
        
        // 双重检查：即使标记不存在，如果已有数据也不创建
        var descriptor = FetchDescriptor<PromptItem>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first, existing.uuid.isEmpty == false {
            // 数据已存在，标记为已初始化并返回
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            return
        }

        // 真正的初始化：创建种子数据
        let seeds = defaultItems()
        for item in seeds {
            context.insert(item)
        }
        for item in seeds {
            VersioningService.ensureBaselineRevision(for: item, in: context, author: "Seed")
        }
        try context.save()
        
        // 标记已完成初始化
        UserDefaults.standard.set(true, forKey: hasSeededKey)
    }

    private static func defaultItems() -> [PromptItem] {
        [
            PromptItem(
                title: "欢迎使用 Sparkify",
                body: """
                你好！欢迎来到 Sparkify。

                这是一个为你这样的 Prompt 工程师和深度LLM玩家设计的工具，旨在将你的提示词管理提升到新高度。忘掉散落在各处的笔记吧，在这里，你的灵感将变得井井有条、一键可用。

                **核心用法三步走**：
                1. 创建模板: 点击右上角的 + 号，开始撰写你的第一个提示词模板。
                2. 定义参数: 在你的提示词中，使用 {} 来包裹任何你希望动态填充的变量（要使用英文变量名哦），比如 {topic} 或 {style}。Sparkify 会自动识别它们，并为你生成专属的输入框。
                3. 使用与复制: 回到这个工作区，找到你的模板，在下方的参数框中填入具体内容。填好后，点击黑色的「复制」按钮，一个完整、即取即用的提示词就准备好了。粘贴到你的 LLM 工具中，开始创作吧！

                **小贴士**：
                - 左侧的列表可以帮你快速切换和管理所有模板。
                - 你可以为模板打上标签，方便以后筛选和查找。

                现在，试试创建你的第一个模板，或者随意修改这份说明书吧。祝你玩得开心！
                """,
                pinned: true,
                tags: ["欢迎", "入门"],
                params: [
                    ParamKV(key: "topic", value: ""),
                    ParamKV(key: "style", value: "")
                ]
            ),
            PromptItem(
                title: "示例 · 闪电总结",
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
