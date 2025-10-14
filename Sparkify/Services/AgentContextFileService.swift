import AppKit
import Foundation
import UniformTypeIdentifiers

struct AgentContextFileService {
    static let shared = AgentContextFileService()

    enum SelectionError: LocalizedError {
        case userCancelled
        case emptySelection

        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "用户取消了文件选择。"
            case .emptySelection:
                return "未选择任何 Markdown 文件。"
            }
        }
    }

    enum FileError: LocalizedError {
        case bookmarkCreationFailed(URL, Error)
        case bookmarkResolutionFailed(String)
        case accessDenied(URL)
        case readFailed(URL, Error)
        case writeFailed(URL, Error)

        var errorDescription: String? {
            switch self {
            case .bookmarkCreationFailed(let url, let error):
                return "无法为 \(url.lastPathComponent) 创建书签：\(error.localizedDescription)"
            case .bookmarkResolutionFailed(let message):
                return "文件书签失效：\(message)"
            case .accessDenied(let url):
                return "没有权限访问 \(url.lastPathComponent)。"
            case .readFailed(let url, let error):
                return "读取 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
            case .writeFailed(let url, let error):
                return "写入 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
            }
        }
    }

    struct SyncResult {
        enum Operation {
            case pull
            case push
        }

        let attachment: PromptFileAttachment
        let url: URL?
        let operation: Operation
        let error: FileError?
        let content: String?

        var isSuccess: Bool { error == nil }
    }

    private init() {}

    @MainActor
    func chooseMarkdownFiles() throws -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = true
        panel.allowedContentTypes = Self.markdownTypes
        panel.prompt = "选择"
        panel.message = "选择一个或多个本地 Markdown 文件。若需显示隐藏文件，请按 ⌘⇧."

        let response = panel.runModal()
        guard response == .OK else {
            throw SelectionError.userCancelled
        }

        let urls = panel.urls.filter { url in
            Self.markdownTypes.contains(where: { url.conforms(to: $0) })
        }

        guard urls.isEmpty == false else {
            throw SelectionError.emptySelection
        }
        return urls
    }

    func makeAttachments(from urls: [URL], startingOrder: Int = 0) throws -> [PromptFileAttachment] {
        var attachments: [PromptFileAttachment] = []
        for (index, url) in urls.enumerated() {
            let bookmark = try createBookmark(for: url)
            let attachment = PromptFileAttachment(
                displayName: url.lastPathComponent,
                bookmarkData: bookmark,
                orderHint: startingOrder + index
            )
            attachments.append(attachment)
        }
        return attachments
    }

    func appendAttachments(_ urls: [URL], to prompt: PromptItem) throws {
        let baseOrder = (prompt.attachments.map(\.orderHint).max() ?? -1) + 1
        let newAttachments = try makeAttachments(from: urls, startingOrder: baseOrder)
        prompt.attachments.append(contentsOf: newAttachments)
        newAttachments.forEach { $0.prompt = prompt }
    }

    func resolveURL(for attachment: PromptFileAttachment) throws -> URL {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: attachment.bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                attachment.bookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
            return url
        } catch let fileError as FileError {
            throw fileError
        } catch {
            throw FileError.bookmarkResolutionFailed(error.localizedDescription)
        }
    }

    func refreshBookmarkIfNeeded(for attachment: PromptFileAttachment, resolvedURL: URL) {
        guard let updatedData = try? resolvedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }
        attachment.bookmarkData = updatedData
    }

    func pullContent(from attachment: PromptFileAttachment) -> SyncResult {
        do {
            let url = try resolveURL(for: attachment)
            guard url.startAccessingSecurityScopedResource() else {
                return SyncResult(attachment: attachment, url: url, operation: .pull, error: .accessDenied(url), content: nil)
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let contents = try String(contentsOf: url, encoding: .utf8)
            attachment.lastSyncedAt = Date()
            attachment.lastErrorMessage = nil
            attachment.displayName = url.lastPathComponent
            refreshBookmarkIfNeeded(for: attachment, resolvedURL: url)
            return SyncResult(attachment: attachment, url: url, operation: .pull, error: nil, content: contents)
        } catch let error as FileError {
            attachment.lastErrorMessage = error.errorDescription
            return SyncResult(attachment: attachment, url: nil, operation: .pull, error: error, content: nil)
        } catch {
            let resolvedError = FileError.readFailed(URL(fileURLWithPath: attachment.displayName), error)
            attachment.lastErrorMessage = resolvedError.errorDescription
            return SyncResult(attachment: attachment, url: nil, operation: .pull, error: resolvedError, content: nil)
        }
    }

    func overwrite(_ body: String, to attachments: [PromptFileAttachment]) -> [SyncResult] {
        attachments.map { overwrite(body, to: $0) }
    }

    func overwrite(_ body: String, to attachment: PromptFileAttachment) -> SyncResult {
        do {
            let url = try resolveURL(for: attachment)
            guard url.startAccessingSecurityScopedResource() else {
                return SyncResult(attachment: attachment, url: url, operation: .push, error: .accessDenied(url), content: nil)
            }
            defer { url.stopAccessingSecurityScopedResource() }

            try body.write(to: url, atomically: true, encoding: .utf8)
            attachment.lastOverwrittenAt = Date()
            attachment.lastErrorMessage = nil
            attachment.displayName = url.lastPathComponent
            refreshBookmarkIfNeeded(for: attachment, resolvedURL: url)
            return SyncResult(attachment: attachment, url: url, operation: .push, error: nil, content: nil)
        } catch let error as FileError {
            attachment.lastErrorMessage = error.errorDescription
            return SyncResult(attachment: attachment, url: nil, operation: .push, error: error, content: nil)
        } catch {
            let resolvedError = FileError.writeFailed(URL(fileURLWithPath: attachment.displayName), error)
            attachment.lastErrorMessage = resolvedError.errorDescription
            return SyncResult(attachment: attachment, url: nil, operation: .push, error: resolvedError, content: nil)
        }
    }

    private func createBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw FileError.bookmarkCreationFailed(url, error)
        }
    }

    private static let markdownTypes: [UTType] = {
        var ordered: [UTType] = []
        var seen = Set<UTType>()
        func append(_ type: UTType?) {
            guard let type, seen.insert(type).inserted else { return }
            ordered.append(type)
        }
        append(UTType(filenameExtension: "md"))
        append(UTType(filenameExtension: "mdown"))
        return ordered
    }()
}

private extension URL {
    func conforms(to type: UTType) -> Bool {
        guard let resourceValues = try? resourceValues(forKeys: [.contentTypeKey]),
              let contentType = resourceValues.contentType else {
            return pathExtension.lowercased() == type.preferredFilenameExtension?.lowercased()
        }
        return contentType.conforms(to: type)
    }
}
