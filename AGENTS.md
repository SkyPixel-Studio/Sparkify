# Repository Guidelines

## Product Design Philosophy
- North Star: help power users turn scattered prompts into reusable templates; every interaction must feel instant and keyboard-first.
- Palette: monochrome foundation with one neon yellow (#E6FF00) accent for high-value actions or unresolved `{param}` placeholders—avoid additional accent colors.
- Layout principles: grid-first card overview for quick parameter fills, detail sheets only for deep editing; HUD toasts stay brief and non-intrusive.
- Reliability promises: autosave on every edit, SwiftData persistence resilient to crashes, and copy actions that never block flow.

## Project Structure & Module Organization
- `Sparkify/` — SwiftUI production code. Key areas: `ContentView.swift` (grid UI + commands), `Services/` (template engine, transfer utilities), and `Models/` (SwiftData models).
- `SparkifyTests/` — XCTest targets, currently covering template parsing and prompt transfer logic.
- `Assets.xcassets/` — App icons and color assets; keep the neon yellow token in sync with design updates.

When adding new feature modules, place view models or helpers in `Services/` unless they persist data (then use `Models/` with SwiftData annotations).

## Build, Test, and Development Commands
- `xcodebuild -scheme Sparkify -destination 'platform=macOS' build` — Fast sanity build; required before pushing.
- `xcodebuild -scheme Sparkify -destination 'platform=macOS' test` — Runs all XCTest bundles. Configure additional destinations (e.g., `arch=x86_64`) if you introduce catalyst targets.
- `xed .` — Opens the workspace in Xcode; useful when editing entitlements or capabilities.

## Coding Style & Naming Conventions
- Swift files use 4-space indentation and trailing commas where SwiftFormat would normally apply. Keep UI constants grouped under `// MARK:` tokens.
- Model types adopt `PromptItem/ParamKV` style: nouns in PascalCase, properties in lowerCamelCase, UUID-backed identifiers named `uuid`.
- View structs end with `View` (e.g., `TemplateCardView`). For internal helpers prefer `private struct` scoped within the owning file.

## Testing Guidelines
- Prefer lightweight unit tests in `SparkifyTests/`. Mirror file paths (e.g., `TemplateEngine.swift` ↔︎ `TemplateEngineTests.swift`).
- Name tests using `testScenarioExpectation` (e.g., `testImportMergesByUUID`). Cover edge cases: placeholder escaping, SwiftData merges, and HUD feedback logic via state assertions when feasible.
- Run `xcodebuild ... test` before merging; attach failing snippets in PRs.

## Commit & Pull Request Guidelines
- Commits typically follow `type: scope` (e.g., `feat: add prompt transfer service`, `fix: tighten param focus binding`). Squash fixups before review.
- PRs should include: summary of user story, screenshots or screen recordings for UI changes (grid, HUD, tagging), and explicit regression checklist (build + tests). Link Linear/Jira ticket IDs when applicable.

## Security & Configuration Tips
- App Sandbox must include **User Selected File Read/Write** to support export dialogs. Validate under **Signing & Capabilities → App Sandbox → File Access**.
- Seed data modifies SwiftData on launch; avoid destructive schema changes without migration notes in the PR description.
