// ScriptManager/Core/GlobalHotkeyManager.swift
import Cocoa
import Carbon
import Combine

/// 架构级增强：基于 Carbon 框架的全局快捷键引擎，支持无限个快捷键的动态注册与分发
public class GlobalHotkeyManager: ObservableObject {
    public static let shared = GlobalHotkeyManager()
    
    @Published public var hotkeyCode: UInt16 {
        didSet { save(); registerMain() }
    }
    @Published public var hotkeyModifiers: UInt32 {
        didSet { save(); registerMain() }
    }
    
    public var mainAction: (() -> Void)?
    private var agentActions: [Int: () -> Void] = [:]
    
    private var mainHotKeyRef: EventHotKeyRef?
    private var agentHotKeyRefs: [Int: EventHotKeyRef] = [:]
    
    private init() {
        let savedCode = UserDefaults.standard.integer(forKey: "hotkeyCode")
        let savedMods = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        
        // 默认主快捷键：Option + Space
        if savedCode == 0 && savedMods == 0 {
            self.hotkeyCode = 49 // Space
            self.hotkeyModifiers = UInt32(optionKey) // Option
        } else {
            self.hotkeyCode = UInt16(savedCode)
            self.hotkeyModifiers = UInt32(savedMods)
        }
        
        setupEventHandler()
        registerMain()
    }
    
    private func save() {
        UserDefaults.standard.set(Int(hotkeyCode), forKey: "hotkeyCode")
        UserDefaults.standard.set(Int(hotkeyModifiers), forKey: "hotkeyModifiers")
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let ptr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        // 架构级修复：使用 GetEventDispatcherTarget() 替代 GetApplicationEventTarget()
        // 彻底解决应用在后台或被挂起时，全局快捷键无法唤醒的致命缺陷
        InstallEventHandler(GetEventDispatcherTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if status == noErr {
                DispatchQueue.main.async {
                    if hotKeyID.id == 1 {
                        manager.mainAction?()
                    } else {
                        manager.agentActions[Int(hotKeyID.id)]?()
                    }
                }
            }
            return noErr
        }, 1, &eventType, ptr, nil)
    }
    
    public func registerMain() {
        if let ref = mainHotKeyRef {
            UnregisterEventHotKey(ref)
            mainHotKeyRef = nil
        }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(1397508690) // 'SMGR'
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(UInt32(hotkeyCode), hotkeyModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &mainHotKeyRef)
        if status != noErr {
            print("[GlobalHotkeyManager] Failed to register main hotkey. Status: \(status)")
        } else {
            print("[GlobalHotkeyManager] Successfully registered main hotkey.")
        }
    }
    
    public func unregisterAllAgentHotkeys() {
        for (_, ref) in agentHotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        agentHotKeyRefs.removeAll()
        agentActions.removeAll()
    }
    
    public func registerAgentHotkey(id: Int, keyCode: UInt16, modifiers: UInt32, action: @escaping () -> Void) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(1397508690) // 'SMGR'
        hotKeyID.id = UInt32(id)
        
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let validRef = ref {
            agentHotKeyRefs[id] = validRef
            agentActions[id] = action
            print("[GlobalHotkeyManager] Successfully registered agent hotkey \(id).")
        } else {
            print("[GlobalHotkeyManager] Failed to register agent hotkey \(id). Status: \(status)")
        }
    }
}