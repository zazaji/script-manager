// ScriptManager/Services/LauncherWindowManager.swift
import Cocoa
import SwiftUI

public class LauncherWindow: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    // 架构级增强：允许窗口在所有空间（Spaces）和全屏应用之上显示
    public override var collectionBehavior: NSWindow.CollectionBehavior {
        get { [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle] }
        set { super.collectionBehavior = newValue }
    }
}

@MainActor
public class LauncherWindowManager {
    public static let shared = LauncherWindowManager()
    private var window: LauncherWindow?

    // 架构级增强：暴露窗口可见性状态，供全局悬浮窗进行智能抑制判断
    public var isVisible: Bool {
        return window?.isVisible ?? false
    }

    private init() {}

    public func show() {
        if let w = window, w.isVisible && w.isKeyWindow {
            hide()
            return
        }

        // 唤起前重置状态
        LauncherViewModel.shared.reset()

        if window == nil {
            let view = LauncherView()
            let hostingController = NSHostingController(
                rootView: view
            )

            let windowWidth = 700
            let windowHeight = 600

            window = LauncherWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: windowWidth,
                    height: windowHeight
                ),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window?.isOpaque = false
            window?.backgroundColor = .clear
            window?.hasShadow = false
            
            // 架构级增强：将层级从 .floating 提升到 .popUpMenu
            // 确保启动器凌驾于绝大多数悬浮窗口（如画中画、其他工具面板）之上
            window?.level = .popUpMenu 
            
            window?.contentViewController = hostingController

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }
        
        // 架构级增强：智能多屏鼠标跟随定位
        // 确保启动器永远出现在用户当前视线所在的屏幕（鼠标所在屏幕）
        if let w = window {
            let mouseLocation = NSEvent.mouseLocation
            if let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                let x = currentScreen.frame.midX - w.frame.width / 2
                let y = currentScreen.frame.midY - w.frame.height / 2
                w.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                w.center()
            }
        }
        
        // 架构级优化：调整唤醒时序，实现真正的“零延迟秒开”
        // 1. 先强制将窗口在屏幕上绘制出来并推到最前端
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        
        // 2. 再向系统请求 App 激活（这一步可能会被系统安全机制短暂阻塞，放在后面不影响视觉呈现）
        NSApp.activate(ignoringOtherApps: true)

        // 3. 霸道抢占输入焦点
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let w = self.window else { return }
            if let tf = self.findTextField(in: w.contentView) {
                w.makeFirstResponder(tf)
                // 唤醒时自动全选输入框内容，方便用户直接打字覆盖旧内容
                if let editor = w.fieldEditor(true, for: tf) as? NSTextView {
                    editor.selectAll(nil)
                }
            }
        }
        
        // 架构级增强：启动器显示时，主动通知 TerminalManager 更新悬浮窗状态（可能需要抑制）
        TerminalManager.shared.updateWidgetState()
    }

    public func hide() {
        window?.orderOut(nil)
        // 架构级增强：启动器隐藏时，主动通知 TerminalManager 更新悬浮窗状态（恢复显示）
        TerminalManager.shared.updateWidgetState()
    }

    @objc func windowDidResignKey() {
        hide()
    }

    public func activateMainWindow() {
        var mainWindow: NSWindow? = nil
        
        for w in NSApp.windows {
            if w !== self.window && !(w is NSPanel) && w.canBecomeMain {
                mainWindow = w
                break
            }
        }
        
        if let w = mainWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let url = Bundle.main.bundleURL
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
        }
    }

    private func findTextField(
        in view: NSView?
    ) -> NSTextField? {
        guard let view = view else { return nil }
        if let textField = view as? NSTextField {
            return textField
        }
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        return nil
    }
}