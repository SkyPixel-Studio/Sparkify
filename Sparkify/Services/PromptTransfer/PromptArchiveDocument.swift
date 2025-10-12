//
//  PromptArchiveDocument.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PromptArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func empty() -> PromptArchiveDocument {
        PromptArchiveDocument(data: Data())
    }
}
