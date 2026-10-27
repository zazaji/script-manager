// ScriptManager/Views/Components/TerminalPanelView.swift
import SwiftUI

public struct TerminalPanelView: View {
    @ObservedObject var terminalManager = TerminalManager.shared
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. 终端 Tab 栏
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(terminalManager.sessions) { session in
                            TerminalTabItem(
                                session: session,
                                isSelected: terminalManager.selectedSessionID == session.id,
                                onSelect: { terminalManager.selectedSessionID = session.id },
                                onClose: { terminalManager.removeSession(id: session.id) }
                            )
                            
                            // 极简分割线
                            Rectangle()
                                .fill(Color(NSColor.separatorColor).opacity(0.3))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { withAnimation { terminalManager.togglePanel() } }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            }
            .frame(height: 32)
            // 整个 Tab 栏的底色
            .background(Color(NSColor.windowBackgroundColor))
            
            // 2. 终端内容区
            ZStack {
                // 架构级修复：随系统主题变化的高级灰，告别纯白瞎眼和死黑不分
                TerminalTheme.backgroundColor
                
                if let selectedID = terminalManager.selectedSessionID,
                   let session = terminalManager.sessions.first(where: { $0.id == selectedID }) {
                    ConsoleTerminalView(session: session).id(session.id)
                } else {
                    Text(Constants.UI.noActiveTerminals).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TerminalTabItem: View {
    @ObservedObject var session: ExecutionSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(session.state == .running ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            
            Text(session.scriptName)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .primary : .secondary)
            
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 8))
            }
            .buttonStyle(.plain)
            .opacity(isSelected ? 1 : 0.5)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        // 架构级修复：选中状态下，底部直接与终端输出区颜色贯通
        .background(isSelected ? TerminalTheme.backgroundColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(Constants.UI.closeTerminalButton) { onClose() }
            Divider()
            Button("Close Others") { TerminalManager.shared.closeOtherSessions(than: session.id) }
            Button("Close All") { TerminalManager.shared.closeAllSessions() }
        }
    }
}