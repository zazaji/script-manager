// ScriptManager/Services/ApplicationManager.swift
import Foundation
import AppKit

/// 架构级增强：系统应用管理器，负责扫描并加载 macOS 安装的应用程序
public class ApplicationManager {
    public static let shared = ApplicationManager()
    
    private init() {}
    
    /// 异步扫描系统应用目录 (架构重构：移除沉重的图标提取和 LaunchServices 校验，实现毫秒级极速扫描)
    public func scanApplications() async -> [ApplicationItem] {
        return await Task.detached(priority: .userInitiated) {
            print("========== APPLICATION SCAN ==========")
            let appDirectories = [
                "/Applications",
                "/System/Applications",
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
            ]
            
            let fileManager = FileManager.default
            var foundApps: [ApplicationItem] = []
            
            for dirPath in appDirectories {
                let url = URL(fileURLWithPath: dirPath)
                print("[Scanning Directory]: \(dirPath)")
                
                do {
                    // 架构级防坑：绝对不要传 .isApplicationKey，否则会触发 LaunchServices 同步阻塞，导致系统级卡死！
                    let contents = try fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                    
                    for fileURL in contents where fileURL.pathExtension.lowercased() == "app" {
                        let name = fileManager.displayName(atPath: fileURL.path)
                        foundApps.append(ApplicationItem(url: fileURL, name: name))
                    }
                } catch {
                    print("[ApplicationManager] Error reading directory \(dirPath): \(error)")
                }
            }
            
            let sortedApps = foundApps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            print("[Scan Complete]: Found \(sortedApps.count) applications.")
            print("======================================")
            return sortedApps
        }.value
    }
    
    /// 运行指定的应用程序
    public func launchApplication(at url: URL) {
        print("[ApplicationManager] Launching: \(url.path)")
        NSWorkspace.shared.open(url)
    }
}