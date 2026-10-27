// ScriptManager/Views/Components/ShortcutRecorderView.swift
import SwiftUI
import Carbon

/// 架构级增强：原生快捷键录制组件，拦截键盘事件并转换为 Carbon 格式
public struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt32
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> ShortcutButton {
        let button = ShortcutButton()
        button.onShortcutChanged = { 
            [weak coordinator = context.coordinator] code, mods in
            coordinator?.updateShortcut(
                keyCode: code,
                modifiers: mods
            )
        }
        return button
    }
    
    public func updateNSView(
        _ nsView: ShortcutButton,
        context: Context
    ) {
        // 刷新 Coordinator 的 parent 避免值类型 Stale Bug
        context.coordinator.parent = self
        nsView.setShortcut(keyCode: keyCode, modifiers: modifiers)
    }
    
    public class Coordinator {
        var parent: ShortcutRecorderView
        
        init(_ parent: ShortcutRecorderView) {
            self.parent = parent
        }
        
        func updateShortcut(keyCode: UInt16, modifiers: UInt32) {
            parent.keyCode = keyCode
            parent.modifiers = modifiers
        }
    }
}

public class ShortcutButton: NSButton {
    var onShortcutChanged: ((UInt16, UInt32) -> Void)?
    private var isRecording = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.bezelStyle = .rounded
        self.target = self
        self.action = #selector(toggleRecording)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func toggleRecording() {
        isRecording = true
        self.title = "Recording... (Press Delete to clear)"
        self.window?.makeFirstResponder(self)
    }
    
    public override func performKeyEquivalent(
        with event: NSEvent
    ) -> Bool {
        if isRecording {
            handleEvent(event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public override func keyDown(with event: NSEvent) {
        if isRecording {
            // 架构级增强：支持按下 Delete 或 Forward Delete 清除快捷键
            if event.keyCode == 51 || event.keyCode == 117 {
                onShortcutChanged?(0, 0)
                isRecording = false
                self.title = "Click to Record"
                return
            }
            handleEvent(event)
        } else {
            super.keyDown(with: event)
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        let nsMods = event.modifierFlags.intersection(
            [.command, .option, .control, .shift]
        )
        if !nsMods.isEmpty {
            let carbonMods = carbonModifiers(from: nsMods)
            onShortcutChanged?(event.keyCode, carbonMods)
            isRecording = false
            setShortcut(keyCode: event.keyCode, modifiers: carbonMods)
        }
    }
    
    func setShortcut(keyCode: UInt16, modifiers: UInt32) {
        if isRecording { return }
        if keyCode == 0 && modifiers == 0 {
            self.title = "Click to Record"
        } else {
            self.title = formatShortcut(keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    private func carbonModifiers(
        from nsModifiers: NSEvent.ModifierFlags
    ) -> UInt32 {
        var carbonMods: UInt32 = 0
        if nsModifiers.contains(.command) {
            carbonMods |= UInt32(cmdKey)
        }
        if nsModifiers.contains(.option) {
            carbonMods |= UInt32(optionKey)
        }
        if nsModifiers.contains(.control) {
            carbonMods |= UInt32(controlKey)
        }
        if nsModifiers.contains(.shift) {
            carbonMods |= UInt32(shiftKey)
        }
        return carbonMods
    }
    
    private func formatShortcut(
        keyCode: UInt16,
        modifiers: UInt32
    ) -> String {
        var str = ""
        if (modifiers & UInt32(controlKey)) != 0 { str += "⌃" }
        if (modifiers & UInt32(optionKey)) != 0 { str += "⌥" }
        if (modifiers & UInt32(shiftKey)) != 0 { str += "⇧" }
        if (modifiers & UInt32(cmdKey)) != 0 { str += "⌘" }
        
        let keyMap: [UInt16: String] = [
            49: "Space", 36: "Enter", 53: "Esc",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H",
            5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I",
            35: "P", 37: "L", 38: "J", 40: "K", 45: "N",
            46: "M", 18: "1", 19: "2", 20: "3", 21: "4",
            23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
            29: "0"
        ]
        str += keyMap[keyCode] ?? String(keyCode)
        return str
    }
}