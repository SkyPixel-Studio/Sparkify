# Sparkify

Sparkify 是由 Guangzhou Meirui Overseas Consultancy Services Co., Ltd.（广州美瑞海外咨询有限公司）维护的 macOS 模板创作客户端。项目以 SwiftUI 为界面框架、SwiftData 为持久化基础，面向高阶用户的 Prompt 模板化需求。

## 系统概览
- 平台：macOS 14 及以上，原生 SwiftUI 应用。
- 数据层：SwiftData 模型负责模板存储，`SeedDataLoader` 在首次启动时写入示例数据。
- 主要能力：模板网格视图、参数化详情编辑、PromptTransfer 文档导入导出、低延迟 HUD/Toast 通知。

## 目录结构
```
Sparkify/                  应用入口与场景装配
 ├─ Views/                 UI 模块（Root、Sidebar、Templates、PromptDetail、Components）
 ├─ Services/              业务逻辑与协调（PromptTransfer、TemplateEngine、SeedDataLoader、UI 服务）
 ├─ Design/                设计令牌与颜色扩展
 └─ Models/                SwiftData 实体与持久化辅助
SparkifyTests/             XCTest 测试目标，覆盖模板解析与传输流程
Assets.xcassets/           图标与颜色资源，包含霓虹黄 `#E6FF00` 强调色
```

## 核心模块
- `TemplateEngine.swift`：解析 `{param}` 占位符，提供模板渲染与格式化工具。
- `PromptTransfer/`：实现导入导出流程，包含详细错误类型扩展。
- `Services/UI/`：集中管理场景动作、HUD/Toast 模型及副作用触发。
- `Views/Components/`：共享的图标、标签、布局组件供各视图复用。

## 构建与测试
```bash
# 构建
xcodebuild -scheme Sparkify -destination 'platform=macOS' build

# 测试
xcodebuild -scheme Sparkify -destination 'platform=macOS' test
```

在推送代码或提交合并请求前请依次运行上述命令，确保可执行文件与测试集在目标环境通过。

## 设计约束
- 采用灰度底色，仅在未处理 `{param}` 与高价值操作上使用霓虹黄 `#E6FF00`。
- 优先网格 + 详情侧栏交互，提供完整键盘操作通路。
- 所有编辑即时自动保存，复制动作不阻塞主流程，并保持 HUD 提示短促非侵扰。

## 贡献流程
- 持久化实体放置于 `Models/`，服务与协调逻辑放置于 `Services/`。
- Swift 文件使用 4 空格缩进，视图结构命名以 `View` 结尾。
- 提交信息遵循 `type: scope` 规范（示例：`fix: prompt transfer merge crash`）。
- PR 中附上 `xcodebuild ... test` 结果摘要，并说明潜在回归或迁移影响。
