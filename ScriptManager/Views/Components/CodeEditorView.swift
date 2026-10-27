// ScriptManager/Views/Components/CodeEditorView.swift
import SwiftUI
import AppKit

/// 基于 NSTextView 封装的轻量级代码编辑器
public struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var language: ScriptType
    var onSave: (() -> Void)? = nil
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.hasVerticalRuler = false
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(
            size: NSSize(
                width: 0,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        let textView = CustomTextView(
            frame: .zero,
            textContainer: textContainer
        )
        textView.onSave = onSave
        textView.language = language
        
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(
            ofSize: 14,
            weight: .regular
        )
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        textStorage.delegate = context.coordinator
        
        scrollView.documentView = textView
        return scrollView
    }
    
    public func updateNSView(
        _ nsView: NSScrollView,
        context: Context
    ) {
        // 关键：在更新时将 Coordinator 的 parent 刷新为最新的 struct
        // 彻底解决由于 SwiftUI 重构导致 Coordinator.parent 变为陈旧拷贝的缺陷
        context.coordinator.parent = self
        
        guard let textView = nsView.documentView 
                as? CustomTextView else { return }
        
        var needsHighlight = false
        
        if textView.language != language {
            textView.language = language
            needsHighlight = true
        }
        
        if textView.string != text {
            textView.string = text
            needsHighlight = false 
        }
        
        if needsHighlight {
            context.coordinator.highlightAll(
                textStorage: textView.textStorage
            )
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, 
                              NSTextViewDelegate,
                              NSTextStorageDelegate {
        var parent: CodeEditorView
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object 
                    as? NSTextView else { return }
            parent.text = textView.string
        }
        
        public func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            highlightAll(textStorage: textStorage)
        }
        
        func highlightAll(textStorage: NSTextStorage?) {
            guard let textStorage = textStorage else { return }
            let string = textStorage.string as NSString
            let fullRange = NSRange(
                location: 0,
                length: string.length
            )
            
            textStorage.removeAttribute(
                .foregroundColor,
                range: fullRange
            )
            textStorage.addAttribute(
                .foregroundColor,
                value: NSColor.textColor,
                range: fullRange
            )
            
            let language = parent.language
            let keywordColor = NSColor.systemPink
            let stringColor = NSColor.systemOrange
            let commentColor = NSColor.systemGreen
            let numberColor = NSColor.systemPurple
            
            let numberRegex = try? NSRegularExpression(
                pattern: "\\b\\d+(\\.\\d+)?\\b"
            )
            numberRegex?.enumerateMatches(
                in: string as String,
                range: fullRange
            ) { match, _, _ in
                if let matchRange = match?.range {
                    textStorage.addAttribute(
                        .foregroundColor,
                        value: numberColor,
                        range: matchRange
                    )
                }
            }
            
            let keywords: [String]
            switch language {
            case .python:
                keywords = [
                    "def", "class", "import", "from", "return",
                    "if", "elif", "else", "for", "while", "try",
                    "except", "with", "as", "pass", "break",
                    "continue", "True", "False", "None", "and",
                    "or", "not", "in", "is", "lambda", "yield",
                    "global", "nonlocal", "del", "assert",
                    "async", "await"
                ]
            case .node:
                keywords = [
                    "function", "class", "import", "export",
                    "return", "if", "else", "for", "while",
                    "try", "catch", "finally", "switch", "case",
                    "default", "break", "continue", "true",
                    "false", "null", "undefined", "var", "let",
                    "const", "new", "this", "super", "typeof",
                    "instanceof", "async", "await", "yield"
                ]
            case .bash:
                keywords = [
                    "if", "then", "elif", "else", "fi", "for",
                    "while", "in", "do", "done", "case", "esac",
                    "function", "return", "echo", "read", "export",
                    "local", "declare", "typeset", "readonly",
                    "shift", "break", "continue", "exit", "true",
                    "false"
                ]
            case .ruby:
                keywords = [
                    "def", "class", "module", "require",
                    "include", "return", "if", "elsif", "else",
                    "unless", "for", "while", "until", "do",
                    "end", "case", "when", "break", "next",
                    "true", "false", "nil", "yield", "super",
                    "self", "begin", "rescue", "ensure"
                ]
            default:
                keywords = []
            }
            
            if !keywords.isEmpty {
                let pattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
                let keywordRegex = try? NSRegularExpression(
                    pattern: pattern
                )
                keywordRegex?.enumerateMatches(
                    in: string as String,
                    range: fullRange
                ) { match, _, _ in
                    if let matchRange = match?.range {
                        textStorage.addAttribute(
                            .foregroundColor,
                            value: keywordColor,
                            range: matchRange
                        )
                    }
                }
            }
            
            let stringPattern = "\".*?\"|'.*?'" 
                + (language == .node ? "|`.*?`" : "")
            let stringRegex = try? NSRegularExpression(
                pattern: stringPattern,
                options: [.dotMatchesLineSeparators]
            )
            stringRegex?.enumerateMatches(
                in: string as String,
                range: fullRange
            ) { match, _, _ in
                if let matchRange = match?.range {
                    textStorage.addAttribute(
                        .foregroundColor,
                        value: stringColor,
                        range: matchRange
                    )
                }
            }
            
            let commentPattern: String
            switch language {
            case .node:
                commentPattern = "//.*|/\\*[\\s\\S]*?\\*/"
            default:
                commentPattern = "#.*"
            }
            let commentRegex = try? NSRegularExpression(
                pattern: commentPattern
            )
            commentRegex?.enumerateMatches(
                in: string as String,
                range: fullRange
            ) { match, _, _ in
                if let matchRange = match?.range {
                    textStorage.addAttribute(
                        .foregroundColor,
                        value: commentColor,
                        range: matchRange
                    )
                }
            }
        }
    }
}