// ScriptManager/Views/Components/ConsoleTerminalView.swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 架构级增强：终端专属的动态色彩系统，完美区分正文区域
public struct TerminalTheme {
    public static var backgroundColor: Color { Color(nsColor) }
    public static var nsColor: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.name == .darkAqua {
                // 深色模式：带有极客感的高级深灰
                return NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            } else {
                // 浅色模式：清晰且不刺眼的冷浅灰，与纯白正文形成鲜明落差
                return NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)
            }
        }
    }
}

/// 独立的控制台终端组件，支持交互式输入与多行选择
public struct ConsoleTerminalView: View {
    @ObservedObject var session: ExecutionSession
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isSecureInput: Bool = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 控制台工具栏 (紧凑型)
            HStack {
                if session.state == .running {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text(Constants.UI.runningScriptButton)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: { session.stop() }) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help(Constants.UI.stopScriptButton)
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(session.state == .success ? Color.blue : (session.state == .failure ? Color.red : Color.gray))
                            .frame(width: 8, height: 8)
                        Text(session.state == .success ? "Success" : (session.state == .failure ? "Failed" : "Idle"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { session.clearLogs() }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help(Constants.UI.clearLogsButton)
                    
                    Button(action: exportLogs) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .help(Constants.UI.exportLogsButton)
                }
                .foregroundColor(.secondary)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            // 工具栏底色使用 windowBackgroundColor 凸显头部层次
            .background(Color(NSColor.windowBackgroundColor))
            
            // 2. 终端输出区
            TerminalTextView(attributedText: $session.attributedLogs)
                .background(TerminalTheme.backgroundColor)
                .onChange(of: session.attributedLogs) { _, newValue in
                    detectPasswordPrompt(newValue.string)
                }
            
            // 3. 交互式输入区
            if session.state == .running {
                Rectangle()
                    .fill(Color(NSColor.separatorColor).opacity(0.5))
                    .frame(height: 1)
                
                HStack(spacing: 8) {
                    Text("❯")
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    
                    Group {
                        if isSecureInput {
                            SecureField(Constants.UI.enterInputPrompt, text: $inputText)
                                .textFieldStyle(.plain)
                                .focused($isInputFocused)
                        } else {
                            TextField(Constants.UI.enterInputPrompt, text: $inputText)
                                .textFieldStyle(.plain)
                                .focused($isInputFocused)
                        }
                    }
                    .font(.system(size: 13, design: .monospaced))
                    // 适配明暗主题的文字颜色
                    .foregroundColor(.primary)
                    .onSubmit { submitInput() }
                    
                    if !inputText.isEmpty {
                        Button(action: submitInput) {
                            Image(systemName: "return")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                // 保持终端底部输入区与内容区浑然一体
                .background(TerminalTheme.backgroundColor)
                .onAppear {
                    isInputFocused = true
                }
            }
        }
        .background(TerminalTheme.backgroundColor)
    }
    
    /// 智能检测密码输入提示
    private func detectPasswordPrompt(_ text: String) {
        let lastPart = text.components(separatedBy: .newlines).last?.lowercased() ?? ""
        let isPassword = lastPart.contains("password") || lastPart.contains("密码")
        
        if isPassword && !isSecureInput {
            isSecureInput = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        } else if !isPassword && isSecureInput && !lastPart.isEmpty {
            isSecureInput = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }
    
    private func submitInput() {
        guard !inputText.isEmpty else { return }
        session.sendInput(inputText)
        inputText = ""
        isInputFocused = true
    }
    
    private func exportLogs() {
        guard session.attributedLogs.length > 0 else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(session.scriptName)_log.txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            let content = session.attributedLogs.string
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                print("[ConsoleTerminalView] Successfully exported logs to \(url.path)")
            } catch {
                print("[ConsoleTerminalView] Failed to export logs: \(error)")
            }
        }
    }
}

/// 基于 NSTextView 的高性能终端渲染组件
struct TerminalTextView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        // 透明背景，交由外层和 NSTextView 控制
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        // 赋予终端原生的灰度质感
        textView.backgroundColor = TerminalTheme.nsColor
        textView.textColor = NSColor.textColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 10, height: 10)
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // 架构级修复：引入容差值，解决浮点数精度导致的自动滚动失效问题
        let isScrolledToBottom = nsView.verticalScroller?.floatValue ?? 0 >= 0.95 || 
                                 nsView.verticalScroller?.isHidden == true
        
        if textView.attributedString() != attributedText {
            textView.textStorage?.setAttributedString(attributedText)
            
            if isScrolledToBottom {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }
}