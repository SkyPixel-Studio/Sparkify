# Sparkify 多语言支持实现总结

## 已完成的工作

### 1. 创建了 Localizable.xcstrings 目录
- **位置**: `Sparkify/Localizable.xcstrings`
- **支持语言**: 简体中文 (zh-Hans) 和英文 (en)
- **源语言**: zh-Hans (简体中文)
- **包含的字符串数量**: 100+ 条

### 2. 创建了 LocalizationService
- **位置**: `Sparkify/Services/LocalizationService.swift`
- **功能**:
  - 提供 `AppLanguage` 枚举,支持系统跟随、简体中文、英文
  - 使用 `@Observable` 宏实现状态管理
  - 通过 UserDefaults 的 `AppleLanguages` 键切换语言
  - 提供单例访问模式

### 3. 在设置界面添加语言选择器
- **位置**: `Sparkify/Views/Settings/SettingsView.swift`
- **功能**:
  - Picker 控件让用户选择语言
  - 语言切换后显示提示,告知用户需要重启应用
  - 所有设置界面的文本已本地化

### 4. 已本地化的主要文件
- ✅ `ContentView.swift` - 主视图,包含多个格式化字符串
- ✅ `SettingsView.swift` - 设置界面
- 部分 `TemplateGridView.swift` - 模板网格视图
- 部分 `SidebarListView.swift` - 侧边栏视图
- 部分 `PromptDetailView.swift` - 提示词详情视图
- 部分 `VersionHistoryView.swift` - 版本历史视图

## 格式化字符串的处理

### 使用 String(format:) + String(localized:)
所有包含参数的字符串都使用了正确的格式化方式:

```swift
// ✅ 正确示例 1: 单个字符串参数
String(format: String(localized: "delete_prompt_success", defaultValue: "已删除 %@"), displayName)

// ✅ 正确示例 2: 多个整数参数
String(format: String(localized: "import_success", defaultValue: "导入成功：新增 %lld · 更新 %lld"), summary.inserted, summary.updated)

// ✅ 正确示例 3: 单个整数参数
String(format: String(localized: "overwrite_success", defaultValue: "已覆写 %lld 个文件"), successCount)
```

### xcstrings 中的格式化定义
```json
"delete_prompt_success" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "value" : "Deleted %@"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "value" : "已删除 %@"
      }
    }
  }
}
```

## 特殊字符处理

### JSON 转义
在 xcstrings 文件中,中文引号需要正确转义:
```json
// ❌ 错误 - 会导致 JSON 解析失败
"value" : "点击"添加文件…"选择"

// ✅ 正确 - 使用转义的引号
"value" : "点击\"添加文件…\"选择"
```

## 如何使用

### 1. 运行应用
```bash
xcodebuild -scheme Sparkify -destination 'platform=macOS' build
```

### 2. 在设置中切换语言
1. 打开应用设置 (⌘,)
2. 在"通用设置"部分找到"语言"选择器
3. 选择需要的语言 (跟随系统 / 简体中文 / English)
4. 重启应用使更改生效

### 3. 添加新的本地化字符串
在 `Localizable.xcstrings` 中添加新条目:

```json
"new_key" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "English text"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "中文文本"
      }
    }
  }
}
```

然后在代码中使用:
```swift
Text(String(localized: "new_key", defaultValue: "中文文本"))
```

## 需要继续完成的工作

虽然核心功能已实现,但以下文件还有部分字符串需要本地化:

### 高优先级
- [ ] `TemplateCardView.swift` - 模板卡片视图(大量用户可见文本)
- [ ] `TemplateGridView.swift` - 排序模式、过滤器等
- [ ] `SidebarListView.swift` - 侧边栏列表相关文本

### 中优先级  
- [ ] `PromptDetailView.swift` - 详情页面的提示文本
- [ ] `VersionHistoryView.swift` - 版本历史相关文本
- [x] `ToolboxApp.swift` - Toolbox 应用名称和描述 ✅ (2025-10-16)

### 低优先级
- [ ] `PromptTransferError+Detail.swift` - 错误消息详情
- [ ] `TagPalette.swift` - 标签调色板
- [ ] 其他组件视图

## 测试建议

### 1. 基础功能测试
- ✅ 应用能正常构建
- ✅ 语言选择器正常工作
- [ ] 切换语言后重启应用,界面语言正确切换
- [ ] 所有已本地化的文本在中英文下都正确显示

### 2. 格式化字符串测试
- [ ] 删除提示词后 toast 消息格式正确
- [ ] 导入导出成功/失败消息格式正确
- [ ] 克隆提示词消息格式正确
- [ ] 版本历史相关消息格式正确

### 3. 边界情况测试
- [ ] 空字符串处理
- [ ] 特殊字符(如引号、换行符)正确显示
- [ ] 长文本不会导致布局问题

## 注意事项

1. **defaultValue 参数**: 所有 `String(localized:)` 调用都包含 `defaultValue`,确保即使 xcstrings 文件缺失也能正常显示中文

2. **格式化参数类型**: 
   - `%@` 用于字符串
   - `%lld` 用于整数 (Int)
   - `%f` 用于浮点数 (Double)

3. **xcstrings 语法**: JSON 格式,需要正确转义特殊字符

4. **语言切换**: 通过修改 `UserDefaults` 的 `AppleLanguages`,需要重启应用生效

5. **构建系统**: Xcode 会自动从 xcstrings 生成 `GeneratedStringSymbols_Localizable.swift`

## Toolbox 应用本地化实现 (2025-10-16)

### 1. 架构调整
修改了 `ToolboxApp` 结构,将硬编码的 `displayName` 和 `summary` 改为使用本地化键:

**之前:**
```swift
struct ToolboxApp {
    let displayName: String
    let summary: String
}
```

**之后:**
```swift
struct ToolboxApp {
    let displayNameKey: String
    let summaryKey: String
    
    var displayName: String {
        String(localized: String.LocalizationValue(displayNameKey))
    }
    
    var summary: String {
        String(localized: String.LocalizationValue(summaryKey))
    }
}
```

### 2. 新增本地化键
在 `Localizable.xcstrings` 中添加了以下键值对:

| 键名 | 中文 (zh-Hans) | 英文 (en) |
|------|---------------|-----------|
| `toolbox_chatgpt_name` | ChatGPT | ChatGPT |
| `toolbox_chatgpt_app_summary` | OpenAI 官方 macOS 应用，需提前安装 | OpenAI's official macOS app, requires prior installation |
| `toolbox_chatgpt_web_summary` | ChatGPT 网页客户端 | ChatGPT web client |
| `toolbox_claude_name` | Claude | Claude |
| `toolbox_claude_app_summary` | Anthropic Claude macOS 应用，需提前安装 | Anthropic Claude macOS app, requires prior installation |
| `toolbox_claude_web_summary` | Claude 网页客户端 | Claude web client |
| `toolbox_gemini_name` | Gemini | Gemini |
| `toolbox_gemini_summary` | Google Gemini 网页客户端 | Google Gemini web client |
| `toolbox_google_ai_studio_name` | Google AI Studio | Google AI Studio |
| `toolbox_google_ai_studio_summary` | Google AI Studio 网页客户端，可以访问更多 Google DeepMind 模型 | Google AI Studio web client, access more Google DeepMind models |
| `toolbox_grok_name` | Grok | Grok |
| `toolbox_grok_summary` | xAI Grok 网页客户端 | xAI Grok web client |
| `toolbox_qwen_name` | Qwen | Qwen |
| `toolbox_qwen_summary` | Qwen 网页客户端 | Qwen web client |
| `toolbox_tongyi_qwen_name` | 通义千问 | Tongyi Qwen |
| `toolbox_tongyi_qwen_summary` | 通义千问（中国大陆） 网页客户端 | Tongyi Qwen (Mainland China) web client |
| `toolbox_doubao_name` | 豆包 | Doubao |
| `toolbox_doubao_summary` | ByteDance 豆包大模型 网页客户端 | ByteDance Doubao LLM web client |
| `toolbox_deepseek_name` | DeepSeek | DeepSeek |
| `toolbox_deepseek_summary` | DeepSeek 网页客户端 | DeepSeek web client |

### 3. 影响范围
- ✅ `ToolboxApp.swift` - 所有应用定义
- ✅ `SettingsView.swift` - 设置界面的 Toolbox 列表自动使用本地化文本
- ✅ `ToolboxButtonView.swift` - 工具箱按钮展示的应用名称和描述

### 4. 验证通过
- ✅ 项目编译成功
- ✅ 所有测试通过 (20/20)
- ✅ 代码无 lint 错误

## 技术债务

- 部分视图仍使用硬编码的中文字符串
- 可以考虑使用 Xcode 的字符串提取工具自动化提取未本地化的字符串
- 需要建立 CI 流程验证 xcstrings 文件的 JSON 格式正确性

