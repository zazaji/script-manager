// ScriptManager/Services/ApplicationManager.swift
import Foundation
import AppKit

/// 架构级增强：系统应用管理器，负责扫描并加载 macOS 安装的应用程序
public class ApplicationManager {
    public static let shared = ApplicationManager()
    
    private init() {}
    
    /// 异步扫描系统应用目录
    public func scanApplications() async -> [ApplicationItem] {
        print("========== APPLICATION SCAN ==========")
        let appDirectories = [
            "/Applications",
            "/System/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        var foundApps: [ApplicationItem] = []
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared
        
        for dirPath in appDirectories {
            let url = URL(fileURLWithPath: dirPath)
            print("[Scanning Directory]: \(dirPath)")
            
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles])
                
                for fileURL in contents {
                    if fileURL.pathExtension.lowercased() == "app" {
                        let name = fileManager.displayName(atPath: fileURL.path)
                        let icon = workspace.icon(forFile: fileURL.path)
                        
                        let item = ApplicationItem(url: fileURL, name: name, icon: icon)
                        foundApps.append(item)
                    }
                }
            } catch {
                print("[ApplicationManager] Error reading directory \(dirPath): \(error)")
            }
        }
        
        // 按名称排序
        let sortedApps = foundApps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        print("[Scan Complete]: Found \(sortedApps.count) applications.")
        print("======================================")
        return sortedApps
    }
    
    /// 运行指定的应用程序
    public func launchApplication(at url: URL) {
        print("[ApplicationManager] Launching: \(url.path)")
        NSWorkspace.shared.open(url)
    }
}