// ScriptManager/Views/Components/CustomTextView.swift
import SwiftUI
import AppKit

/// 独立的自定义 NSTextView，提供代码级的编辑拦截、缩进与快捷键功能
class CustomTextView: NSTextView {
    var onSave: (() -> Void)?
    var language: ScriptType = .unknown
    
    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
        
        if modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers {
                switch chars {
                case "s":
                    onSave?()
                    return
                case "f":
                    let menuItem = NSMenuItem(
                        title: "",
                        action: #selector(
                            NSTextView.performFindPanelAction(_:)
                        ),
                        keyEquivalent: ""
                    )
                    menuItem.tag = 1 // showFindInterface
                    self.performFindPanelAction(menuItem)
                    return
                case "r":
                    let menuItem = NSMenuItem(
                        title: "",
                        action: #selector(
                            NSTextView.performFindPanelAction(_:)
                        ),
                        keyEquivalent: ""
                    )
                    menuItem.tag = 12 // showReplaceInterface
                    self.performFindPanelAction(menuItem)
                    return
                case "/":
                    toggleComment()
                    return
                default:
                    break
                }
            }
        }
        
        // Tab 缩进处理
        if event.keyCode == 48 { // Tab
            if modifierFlags.contains(.shift) {
                unindent()
            } else {
                indent()
            }
            return
        }
        
        // 快捷分页处理
        if event.keyCode == 116 { // Page Up
            self.pageUp(nil)
            return
        }
        if event.keyCode == 121 { // Page Down
            self.pageDown(nil)
            return
        }
        
        super.keyDown(with: event)
    }
    
    private func toggleComment() {
        let commentPrefix = (language == .node) ? "//" : "#"
        let range = self.selectedRange()
        let string = self.string as NSString
        
        let lineRange = string.lineRange(for: range)
        let selectedText = string.substring(with: lineRange)
        
        var lines: [String] = []
        selectedText.enumerateSubstrings(
            in: selectedText.startIndex..<selectedText.endIndex,
            options: .byLines
        ) { substring, _, _, _ in
            if let substring = substring {
                lines.append(substring)
            }
        }
        
        if lines.isEmpty {
            let replacement = commentPrefix + " " 
                + (selectedText as String)
            if self.shouldChangeText(
                in: lineRange,
                replacementString: replacement
            ) {
                self.replaceCharacters(
                    in: lineRange,
                    with: replacement
                )
                self.didChangeText()
            }
            return
        }
        
        let allCommented = lines.allSatisfy {
            $0.trimmingCharacters(in: .whitespaces)
                .hasPrefix(commentPrefix)
        }
        
        var processedLines: [String] = []
        for line in lines {
            if allCommented {
                if let range = line.range(of: commentPrefix) {
                    var newLine = line
                    newLine.removeSubrange(range)
                    processedLines.append(newLine)
                } else {
                    processedLines.append(line)
                }
            } else {
                processedLines.append(commentPrefix + " " + line)
            }
        }
        
        var replacementText = processedLines
            .joined(separator: "\n")
        if selectedText.hasSuffix("\n") {
            replacementText += "\n"
        }
        
        if self.shouldChangeText(
            in: lineRange,
            replacementString: replacementText
        ) {
            self.replaceCharacters(
                in: lineRange,
                with: replacementText
            )
            self.didChangeText()
        }
    }
    
    private func indent() {
        let range = self.selectedRange()
        let string = self.string as NSString
        let lineRange = string.lineRange(for: range)
        let selectedText = string.substring(with: lineRange)
        
        var lines: [String] = []
        selectedText.enumerateSubstrings(
            in: selectedText.startIndex..<selectedText.endIndex,
            options: .byLines
        ) { substring, _, _, _ in
            if let substring = substring {
                lines.append(substring)
            }
        }
        
        if lines.isEmpty {
            let replacement = "    " + (selectedText as String)
            if self.shouldChangeText(
                in: lineRange,
                replacementString: replacement
            ) {
                self.replaceCharacters(
                    in: lineRange,
                    with: replacement
                )
                self.didChangeText()
            }
            return
        }
        
        let processedLines = lines.map { "    " + $0 }
        var replacementText = processedLines
            .joined(separator: "\n")
        if selectedText.hasSuffix("\n") {
            replacementText += "\n"
        }
        
        if self.shouldChangeText(
            in: lineRange,
            replacementString: replacementText
        ) {
            self.replaceCharacters(
                in: lineRange,
                with: replacementText
            )
            self.didChangeText()
        }
    }
    
    private func unindent() {
        let range = self.selectedRange()
        let string = self.string as NSString
        let lineRange = string.lineRange(for: range)
        let selectedText = string.substring(with: lineRange)
        
        var lines: [String] = []
        selectedText.enumerateSubstrings(
            in: selectedText.startIndex..<selectedText.endIndex,
            options: .byLines
        ) { substring, _, _, _ in
            if let substring = substring {
                lines.append(substring)
            }
        }
        
        if lines.isEmpty {
            var replacement = selectedText as String
            if replacement.hasPrefix("    ") {
                replacement.removeFirst(4)
            } else if replacement.hasPrefix("\t") {
                replacement.removeFirst(1)
            }
            if self.shouldChangeText(
                in: lineRange,
                replacementString: replacement
            ) {
                self.replaceCharacters(
                    in: lineRange,
                    with: replacement
                )
                self.didChangeText()
            }
            return
        }
        
        let processedLines = lines.map { line -> String in
            if line.hasPrefix("    ") {
                return String(line.dropFirst(4))
            } else if line.hasPrefix("\t") {
                return String(line.dropFirst(1))
            }
            return line
        }
        
        var replacementText = processedLines
            .joined(separator: "\n")
        if selectedText.hasSuffix("\n") {
            replacementText += "\n"
        }
        
        if self.shouldChangeText(
            in: lineRange,
            replacementString: replacementText
        ) {
            self.replaceCharacters(
                in: lineRange,
                with: replacementText
            )
            self.didChangeText()
        }
    }
}