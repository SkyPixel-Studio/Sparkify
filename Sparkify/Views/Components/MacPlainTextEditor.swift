//
//  MacPlainTextEditor.swift
//  Sparkify
//
//  Created on 2025/10/26.
//

import SwiftUI
import AppKit

/// A plain text editor that disables all macOS "smart" text substitutions.
/// This prevents automatic quote/dash replacement and other autocorrections.
struct MacPlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 15, weight: .regular)
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacPlainTextEditor
        
        init(_ parent: MacPlainTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollablePlainDocumentContentTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        // 关键：彻底关闭所有"聪明替换"功能
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        
        // 设置样式
        textView.font = font
        textView.textColor = NSColor.textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        
        // 设置文本容器的属性
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
        textView.delegate = context.coordinator
        textView.string = text
        
        // ScrollView 样式
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // 只在内容真正不同时才更新，避免光标跳动
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            
            // 尝试恢复光标位置
            let newLength = (text as NSString).length
            if selectedRange.location <= newLength {
                textView.setSelectedRange(selectedRange)
            }
        }
        
        // 更新字体（如果需要）
        if textView.font != font {
            textView.font = font
        }
    }
}

