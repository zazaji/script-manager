// ScriptManager/Views/Components/TaskWidgetView.swift
import SwiftUI

/// 架构级增强：独立的日志渲染组件，确保仅在日志更新时局部刷新，提升性能
struct TaskWidgetLogView: View {
    @ObservedObject var session: ExecutionSession
    
    var body: some View {
        Text(session.latestLogLine)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.9))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            .animation(.none, value: session.latestLogLine)
    }
}

/// 架构级增强：全局悬浮任务指示器 UI 组件
public struct TaskWidgetView: View {
    @ObservedObject var manager = TaskWidgetManager.shared
    @State private var isHovered = false
    @State private var rotation: Double = 0

    public var body: some View {
        Group {
            if manager.state != .hidden {
                HStack(alignment: .top, spacing: 12) {
                    iconView
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Text(subtitleText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // 架构级增强：实时渲染滚动日志
                        if case .running(let session) = manager.state {
                            TaskWidgetLogView(session: session)
                        }
                    }
                    
                    Spacer()
                    
                    if isHovered {
                        Button(action: { manager.updateState(.hidden) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    WidgetVisualEffectView(material: .popover, blendingMode: .behindWindow)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(borderColor, lineWidth: 1.5)
                )
                .shadow(color: shadowColor.opacity(0.3), radius: 10, x: 0, y: 5)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovered = hovering
                    }
                }
                .onTapGesture {
                    manager.openDetails()
                }
                .onAppear {
                    // 启动无限旋转动画
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.state)
        .padding(10) // 为阴影留出空间
    }

    @ViewBuilder
    private var iconView: some View {
        switch manager.state {
        case .running(let session):
            let isAI = session.scriptName.hasPrefix("AI Task")
            if isAI {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.purple)
                    .rotationEffect(.degrees(rotation))
            } else {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(rotation))
            }
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.red)
        case .hidden:
            EmptyView()
        }
    }

    private var titleText: String {
        switch manager.state {
        case .running: return "Task Running"
        case .success: return "Task Completed"
        case .failure: return "Task Failed"
        case .hidden: return ""
        }
    }

    private var subtitleText: String {
        switch manager.state {
        case .running(let session):
            return session.scriptName
        case .success(let name), .failure(let name):
            return name
        case .hidden:
            return ""
        }
    }

    private var borderColor: Color {
        switch manager.state {
        case .running(let session):
            let isAI = session.scriptName.hasPrefix("AI Task")
            return (isAI ? Color.purple : Color.blue).opacity(0.5)
        case .success: return Color.green.opacity(0.5)
        case .failure: return Color.red.opacity(0.5)
        case .hidden: return .clear
        }
    }

    private var shadowColor: Color {
        switch manager.state {
        case .running(let session):
            let isAI = session.scriptName.hasPrefix("AI Task")
            return isAI ? Color.purple : Color.blue
        case .success: return Color.green
        case .failure: return Color.red
        case .hidden: return .clear
        }
    }
}

/// 内部私有的毛玻璃组件，避免与 LauncherView 中的组件冲突
private struct WidgetVisualEffectView: NSViewRepresentable {
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