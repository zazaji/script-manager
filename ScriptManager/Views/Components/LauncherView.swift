// ScriptManager/Views/Components/LauncherView.swift
import SwiftUI
import AppKit

public struct LauncherView: View {
    @ObservedObject private var viewModel = LauncherViewModel.shared

    // 架构级增强：动态匹配当前输入的 Agent，驱动 UI 变化
    private var matchedAgent: AIAgentConfiguration? {
        for agent in AppStateManager.shared.aiAgents {
            if !agent.prefix.isEmpty && viewModel.searchText.hasPrefix(agent.prefix) {
                return agent
            }
        }
        return nil
    }

    // 公式模式（= 前缀，Agent 未命中时），与 LauncherViewModel.filterItems 的判定保持一致
    private var isFormulaMode: Bool {
        viewModel.searchText.hasPrefix("=") || viewModel.searchText.hasPrefix("＝")
    }

    private var searchIcon: String {
        if matchedAgent == nil && isFormulaMode { return "equal.circle" }
        return matchedAgent?.icon ?? "magnifyingglass"
    }

    private var searchIconColor: Color {
        if matchedAgent == nil && isFormulaMode { return .orange }
        return matchedAgent?.uiColor ?? .secondary
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // 搜索框区域
                HStack(spacing: 12) {
                    Image(systemName: searchIcon)
                        .font(.system(size: 22))
                        .foregroundColor(searchIconColor)
                    
                    LauncherTextField(
                        text: $viewModel.searchText,
                        onUp: viewModel.moveUp,
                        onDown: viewModel.moveDown,
                        onEnter: { inTerminal in viewModel.executeSelected(inTerminal: inTerminal) },
                        onTab: viewModel.autoFill,
                        onEsc: { LauncherWindowManager.shared.hide() }
                    )
                    .frame(maxWidth: .infinity, minHeight: 50)

                    Button(action: { viewModel.refreshData() }) {
                        Group {
                            switch viewModel.refreshState {
                            case .refreshing:
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 20, height: 20)
                            case .completed:
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.green)
                            case .idle:
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help(Constants.UI.refreshWorkspaceTooltip)

                    Button(action: {
                        LauncherWindowManager.shared.hide()
                        LauncherWindowManager.shared.activateMainWindow()
                    }) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Open Main Window")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                Divider()
                    .background(Color(NSColor.separatorColor).opacity(0.5))

                if let session = viewModel.currentSession {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: { viewModel.closeCurrentSession() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text(Constants.UI.backToSearchButton)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            Text(session.scriptName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.windowBackgroundColor))
                        
                        Divider()
                        
                        ConsoleTerminalView(session: session)
                    }
                    .frame(height: 400)
                    .transition(.opacity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            if viewModel.items.isEmpty {
                                VStack {
                                    Spacer()
                                    if WorkspaceViewModel.shared.applications.isEmpty && WorkspaceViewModel.shared.allScripts.isEmpty {
                                        ProgressView("Loading...")
                                            .controlSize(.small)
                                    } else {
                                        Text("No results found")
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .frame(height: 400)
                            } else {
                                LazyVStack(spacing: 4) {
                                    ForEach(viewModel.items) { item in
                                        let idx = viewModel.selectedIndex
                                        let isSel = viewModel.items.indices.contains(idx) && viewModel.items[idx].id == item.id
                                        
                                        LauncherItemRow(
                                            item: item,
                                            isSelected: isSel,
                                            formulaCopied: viewModel.formulaCopied && item.id == "formula_current"
                                        )
                                            .id(item.id)
                                            .onTapGesture {
                                                tapAction(for: item)
                                            }
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                            }
                        }
                        .frame(height: 400)
                        .onChange(of: viewModel.selectedIndex) { _, newIdx in
                            scrollToIdx(newIdx, proxy: proxy)
                        }
                    }
                }
            }
            .frame(width: 700)
            .background(
                VisualEffectView(
                    material: .popover,
                    blendingMode: .behindWindow
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            
            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tapAction(for item: LauncherItem) {
        if let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
            viewModel.selectedIndex = index
            viewModel.executeSelected(inTerminal: true)
        }
    }

    private func scrollToIdx(_ idx: Int, proxy: ScrollViewProxy) {
        if viewModel.items.indices.contains(idx) {
            let id = viewModel.items[idx].id
            withAnimation(.easeInOut(duration: 0.1)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}

struct LauncherItemRow: View {
    let item: LauncherItem
    let isSelected: Bool
    var formulaCopied: Bool = false

    private var isScript: Bool {
        if case .script = item.type { return true }
        return false
    }
    
    private var isAITask: Bool {
        if case .aiTask = item.type { return true }
        return false
    }

    private var isFormula: Bool {
        if case .formula = item.type { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let appURL = item.appURL {
                    AppIconView(url: appURL)
                        .frame(width: 32, height: 32)
                } else if let iconName = item.iconName,
                          let iconColor = item.iconColor {
                    Image(systemName: iconName)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(isSelected ? .white : iconColor)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "terminal")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(isSelected ? .white : .gray)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)

                if let desc = item.description {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
                
                if let hint = item.parametersHint, !hint.isEmpty {
                    Text(formulaCopied ? "✓ " + Constants.UI.copiedToast : hint)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(formulaCopied ? .green : (isSelected ? .white.opacity(0.9) : Color(NSColor.systemBlue).opacity(0.8)))
                        .lineLimit(1)
                }
            }
            Spacer()

            if isScript || isAITask {
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Image(systemName: "return")
                        Text("Terminal")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                    
                    if !isAITask {
                        HStack(spacing: 2) {
                            Text("⌘/⌃")
                            Image(systemName: "return")
                            Text("App")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .foregroundColor(isSelected ? .white : .secondary)
            } else {
                Text(isFormula ? "Copy" : "Open")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? (isAITask ? (item.iconColor ?? Color.accentColor) : (isFormula ? Color.orange : Color.accentColor)) : Color.clear)
        .cornerRadius(10)
        .contentShape(Rectangle())
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

class FocusableTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didBecomeKey),
                name: NSApplication.didBecomeActiveNotification,
                object: nil
            )
            
            DispatchQueue.main.async {
                window.makeFirstResponder(self)
            }
        }
    }

    @objc func didBecomeKey() {
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
            if let editor = self.window?.fieldEditor(true, for: self) as? NSTextView {
                editor.selectAll(nil)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct LauncherTextField: NSViewRepresentable {
    @Binding var text: String
    var onUp: () -> Void
    var onDown: () -> Void
    var onEnter: (Bool) -> Void
    var onTab: () -> Void
    var onEsc: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = FocusableTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = .systemFont(ofSize: 24, weight: .light)
        tf.textColor = .labelColor
        tf.usesSingleLineMode = true
        tf.lineBreakMode = .byTruncatingTail
        tf.placeholderString = Constants.UI.launcherSearchPrompt
        tf.delegate = context.coordinator
        tf.setContentHuggingPriority(.init(rawValue: 249), for: .horizontal)
        tf.setContentCompressionResistancePriority(.init(rawValue: 249), for: .horizontal)
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // 架构级增强：动态匹配前缀并渲染对应的主题色
        var matchedColor: NSColor = .labelColor
        for agent in AppStateManager.shared.aiAgents {
            if !agent.prefix.isEmpty && text.hasPrefix(agent.prefix) {
                switch agent.themeColor {
                case "purple": matchedColor = .systemPurple
                case "blue": matchedColor = .systemBlue
                case "orange": matchedColor = .systemOrange
                case "green": matchedColor = .systemGreen
                case "red": matchedColor = .systemRed
                case "gray": matchedColor = .systemGray
                default: matchedColor = .systemBlue
                }
                break
            }
        }
        // Agent 未命中且为公式模式（= / ＝ 前缀）时渲染橙色
        if matchedColor == .labelColor, text.hasPrefix("=") || text.hasPrefix("＝") {
            matchedColor = .systemOrange
        }
        nsView.textColor = matchedColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LauncherTextField

        init(_ parent: LauncherTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField {
                self.parent.text = tf.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            let modifiers = NSApp.currentEvent?.modifierFlags ?? []
            let isCmdOrCtrl = modifiers.contains(.command) || modifiers.contains(.control)
            
            if selector == #selector(NSResponder.moveUp(_:)) {
                DispatchQueue.main.async { self.parent.onUp() }
                return true
            } else if selector == #selector(NSResponder.moveDown(_:)) {
                DispatchQueue.main.async { self.parent.onDown() }
                return true
            } else if selector == #selector(NSResponder.insertNewline(_:)) || 
                      selector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                DispatchQueue.main.async { self.parent.onEnter(!isCmdOrCtrl) }
                return true
            } else if selector == #selector(NSResponder.insertTab(_:)) {
                DispatchQueue.main.async { self.parent.onTab() }
                return true
            } else if selector == #selector(NSResponder.cancelOperation(_:)) {
                // Esc 关闭启动器（此前无处理，浮层只能靠失焦或快捷键收起）
                DispatchQueue.main.async { self.parent.onEsc() }
                return true
            }
            return false
        }
    }
}