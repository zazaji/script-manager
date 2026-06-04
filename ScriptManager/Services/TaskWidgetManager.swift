// ScriptManager/Services/TaskWidgetManager.swift
import Cocoa
import SwiftUI
import Combine

public enum TaskWidgetState: Equatable {
    case hidden
    case running(ExecutionSession)
    case success(String)
    case failure(String)
    
    public static func == (lhs: TaskWidgetState, rhs: TaskWidgetState) -> Bool {
        switch (lhs, rhs) {
        case (.hidden, .hidden): return true
        case (.running(let s1), .running(let s2)): return s1.id == s2.id
        case (.success(let s1), .success(let s2)): return s1 == s2
        case (.failure(let s1), .failure(let s2)): return s1 == s2
        default: return false
        }
    }
}

/// 架构级增强：全局悬浮任务指示器管理器 (Dynamic Island 风格)
@MainActor
public class TaskWidgetManager: ObservableObject {
    public static let shared = TaskWidgetManager()

    @Published public var state: TaskWidgetState = .hidden
    private var window: NSPanel?
    private var hideTask: Task<Void, Never>?

    private init() {}

    /// 初始化悬浮窗口，在 App 启动时调用
    public func setup() {
        let view = TaskWidgetView()
        let controller = NSHostingController(rootView: view)
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        // 架构级增强：加大悬浮窗尺寸，为日志滚动留出充裕空间
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // 阴影交由 SwiftUI 内部绘制，更加细腻
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true // 允许用户拖拽移动

        // 默认定位在屏幕右上角，类似于系统通知的位置
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 340
            let y = screen.visibleFrame.maxY - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.contentViewController = controller
        self.window = panel
    }

    /// 更新悬浮窗状态
    public func updateState(_ newState: TaskWidgetState) {
        self.state = newState
        hideTask?.cancel() // 取消之前的自动隐藏任务

        switch newState {
        case .hidden:
            window?.orderOut(nil)
        case .running:
            window?.orderFront(nil)
        case .success, .failure:
            window?.orderFront(nil)
            // 任务完成后，停留 5 秒自动隐藏
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled {
                    self.state = .hidden
                    self.window?.orderOut(nil)
                }
            }
        }
    }

    /// 用户点击悬浮窗时，打开主界面并展示终端详情
    public func openDetails() {
        updateState(.hidden)
        LauncherWindowManager.shared.activateMainWindow()
        TerminalManager.shared.isPanelVisible = true
    }
}