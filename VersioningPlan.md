# Versioning Feature Best Practices

- 版本快照要完整可还原：保留标题、正文、标签、参数，保证历史版本可以随时恢复或做 Diff。
- Diff 计算放到读取链路：保存时只写快照，展示时用轻量服务生成“增删”片段，避免写入时过度开销。
- 压缩版本数量与性能：支持仅存最近 N 次或启用手动“里程碑”标记，避免 SwiftData 存储膨胀。
- UI 上红绿高亮且键盘友好：分栏展示版本列表和 Diff 详情，支持 `⌘⌥↑/↓` 快速切换，保持 Sparkify 的快节奏体验。
- 与导入导出对齐：PromptTransfer 保持兼容，默认不带历史，必要时提供选项，防止跨环境导入爆炸。

# 行动计划

1. **数据模型与迁移**
   - 新增 `PromptRevision` `@Model`，字段含 `uuid`、关联 `prompt`、`createdAt`、`author`（可默认“Local”）、`titleSnapshot`、`bodySnapshot`、`tagsSnapshot`、`paramsSnapshot`（可序列化成 `[ParamRevision]`）以及 `isMilestone` 标记。
   - 在 `PromptItem` 增加 `@Relationship` 指向 revisions 并按时间排序（`Sparkify/Models/PromptModels.swift:33` 附近扩展）。
   - 为未来迁移预留 schema version，更新 `SeedDataLoader`，初始模板至少有一个基线版本。

2. **版本捕捉服务**
   - 新建 `VersioningService`（放 `Sparkify/Services/`），封装：
     1. `captureRevision(for: PromptItem, context:)`：比对最新一条 revision，若有差异则写入新快照。
     2. `recentRevisions(for: PromptItem, limit:)`、`makeDiff(from:to:)` 等查询接口。
   - 采用 JSON 编码的 params 快照，序列化/反序列化集中处理，免得破坏 `PromptItem.params` 逻辑。

3. **保存钩子**
   - 在 `saveDraftAndDismiss()` 里，在 `modelContext.save()` 前调用 `VersioningService.captureRevision`（`Sparkify/Views/PromptDetail/PromptDetailView.swift:373`），确保每次“保存”都会生成新版本。
   - 如果后续引入自动保存，可在 `modelContext.save()` 成功回调里调用以防多次触发；同时做最近版本去重（内容一致就跳过）。

4. **Diff 计算实现**
   - 在 `VersioningService` 内使用 `CollectionDifference` 对“按词 token 化”的数组求 diff；封装为 `DiffSegment`（`kind: .added/.removed/.kept`，`text` 字符串）。
   - 对标题、正文、标签、参数分别计算 diff，并提供汇总结构，方便 UI 按区块渲染。
   - 需要的话引入三方算法（如 Myers diff）也可以，但先用标准库即可。

5. **UI 展示**
   - 在 `PromptDetailView` 新增 “版本历史” 分页或页脚 Tab：左侧为时间线/列表，右侧为 diff 详情。
   - Diff 详情用 `Text` + `AttributedString` 或自定义视图呈现红底/绿底（与北极黄强调色保持协调，删除可用半透明红）。
   - 支持版本之间切换、比较任意两次、恢复旧版本（恢复按钮直接把快照灌入 `PromptDraft`）。
   - 给 `Sidebar` 或 `TemplateGridView` 增加版本数量提示/最新更新时间（可选）。

6. **导入导出与备份**
   - 更新 `PromptTransferService`，默认忽略 `PromptRevision`；在需要时（比如设置里开启“导出包含历史”）再写入。
   - 若导入数据包含 revision，提供合并策略（按时间追加、冲突时保留本地）。

7. **清理与配置**
   - 增加设置项：版本上限、是否保留自动保存版本、是否开启里程碑标记。
   - 提供定期清理脚本或后台任务，删除超限版本但保留每个里程碑。
   - 在 `SettingsView` 增加 UI，让用户调节策略。

8. **测试与回归**
   - 新建 `VersioningServiceTests` 覆盖：新版本捕捉、重复保存去重、Diff 结果、恢复逻辑。
   - UI 层写 `Preview` 或 UI test 验证 diff 渲染不会崩。
   - 手动走通导入导出、恢复旧版本等关键路径。

