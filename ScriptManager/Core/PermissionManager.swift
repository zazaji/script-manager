// ScriptManager/Core/PermissionManager.swift
import Foundation
import AppKit
import Combine

public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var hasFDA: Bool = false
    
    private init() {
        checkFDA()
    }

    /// 架构级防坑：检测当前 App 是否仍然运行在沙盒环境中
    public var isSandboxed: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
    
    /// 获取当前 App 的 Bundle Identifier
    public var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.unknown.app"
    }
    
    public func checkFDA() {
        self.hasFDA = hasFullDiskAccess()
    }

    public func hasFullDiskAccess() -> Bool {
        print("========== PERMISSION CHECK ==========")
        
        // 1. 拦截沙盒残留
        if isSandboxed {
            print("[PermissionManager] ⚠️ WARNING: App is running in Sandbox!")
            print("[PermissionManager] Full Disk Access will NOT work. Please remove App Sandbox from .entitlements.")
            print("======================================")
            return false
        }

        // 2. 多重探针机制 (Multi-Probe Detection)
        let protectedPaths = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "/private/var/db/TCC/TCC.db",
            NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
            NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        ]
        
        for path in protectedPaths {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                let isReadable = FileManager.default.isReadableFile(atPath: path)
                print("[PermissionManager] Probe [\(path)] -> Exists: YES | Readable: \(isReadable ? "YES" : "NO")")
                if isReadable {
                    print("[PermissionManager] Result: GRANTED (via file probe)")
                    print("======================================")
                    return true
                }
            } else {
                print("[PermissionManager] Probe[\(path)] -> Exists: NO")
            }
        }
        
        // 3. 终极探针：尝试读取受保护的目录内容
        let testDir = NSHomeDirectory() + "/Library/Messages"
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: testDir, isDirectory: &isDir) {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: testDir)
                print("[PermissionManager] Result: GRANTED (via directory probe \(testDir))")
                print("======================================")
                return true
            } catch {
                print("[PermissionManager] Directory probe failed: \(error.localizedDescription)")
            }
        }
        
        print("[PermissionManager] Result: DENIED")
        print("======================================")
        return false
    }

    public func openSystemSettingsForFDA() {
        print("[PermissionManager] Opening System Settings for Full Disk Access.")
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        guard let url = URL(string: urlString) else {
            print("[PermissionManager] Error: Invalid URL for System Settings.")
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    /// 在 Finder 中高亮显示当前 App，方便用户拖拽到系统设置中
    public func revealAppInFinder() {
        let bundleURL = Bundle.main.bundleURL
        print("[PermissionManager] Revealing app in Finder at \(bundleURL.path)")
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }
    
    /// 复制 TCC 重置命令到剪贴板，用于解决 macOS TCC 缓存 Bug
    public func copyTCCResetCommand() {
        let command = "tccutil reset SystemPolicyAllFiles \(bundleIdentifier)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        print("[PermissionManager] Copied TCC reset command to clipboard: \(command)")
    }
}