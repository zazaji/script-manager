// ScriptManager/Services/ApplicationManager.swift
import Foundation
import AppKit

/// 架构级增强：系统应用管理器，负责扫描并加载 macOS 安装的应用程序
public class ApplicationManager {
    public static let shared = ApplicationManager()
    
    private init() {}
    
    /// 异步扫描系统应用目录 (架构重构：移除沉重的图标提取和 LaunchServices 校验，实现毫秒级极速扫描)
    public func scanApplications() async -> [ApplicationItem] {
        // 架构级防坑：项目开启 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor，模型默认主线程隔离。
        // 后台线程只做纯文件枚举并返回元组，ApplicationItem 的构造与排序回到调用方上下文
        let found: [(url: URL, name: String)] = await Task.detached(priority: .userInitiated) {
            print("========== APPLICATION SCAN ==========")
            let appDirectories = [
                "/Applications",
                "/System/Applications",
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
            ]

            let fileManager = FileManager.default
            var foundApps: [(url: URL, name: String)] = []

            for dirPath in appDirectories {
                print("[Scanning Directory]: \(dirPath)")
                Self.scanDirectoryRecursively(
                    at: URL(fileURLWithPath: dirPath),
                    depth: 1,
                    fileManager: fileManager,
                    into: &foundApps
                )
            }

            print("[Scan Complete]: Found \(foundApps.count) applications.")
            print("======================================")
            return foundApps
        }.value

        return found
            .map { ApplicationItem(url: $0.url, name: $0.name) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// 递归扫描深度上限：Adobe 系安装器把 .app 包得很深（Creative Cloud 在
    /// /Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud.app，第 4 层），
    /// 深度 5 留一档余量；再深的基本是应用私有数据
    private static let maxScanDepth = 5

    /// 递归枚举目录树收集 .app。
    /// 架构级防坑（三条缺一不可）：
    /// 1. 绝对不要传 .isApplicationKey，否则会触发 LaunchServices 同步阻塞，导致系统级卡死！
    ///    递归场景下代价被放大，因此只按扩展名 `.app` 过滤；
    /// 2. 发现 .app 后不进入 bundle 内部，否则 Photoshop 等大型应用的内嵌辅助组件
    ///    （如 AdobeCrashReport.app）会被误当作独立应用列出来；
    /// 3. 符号链接目录不下钻，防止递归进入链接环导致无限遍历。
    private nonisolated static func scanDirectoryRecursively(
        at url: URL,
        depth: Int,
        fileManager: FileManager,
        into foundApps: inout [(url: URL, name: String)]
    ) {
        guard depth <= maxScanDepth else { return }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            print("[ApplicationManager] Error reading directory \(url.path): \(error)")
            return
        }

        for fileURL in contents {
            if fileURL.pathExtension.lowercased() == "app" {
                let name = fileManager.displayName(atPath: fileURL.path)
                foundApps.append((url: fileURL, name: name))
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isRealDirectory = (values?.isDirectory ?? false) && !(values?.isSymbolicLink ?? true)
            if isRealDirectory {
                scanDirectoryRecursively(
                    at: fileURL,
                    depth: depth + 1,
                    fileManager: fileManager,
                    into: &foundApps
                )
            }
        }
    }
    
    /// 运行指定的应用程序
    /// 架构级防坑：必须用异步 openApplication(configuration:completionHandler:)，不要用同步的
    /// NSWorkspace.shared.open(_:)。后者在主线程调用会阻塞直到目标 App 加载完，慢应用会导致
    /// ScriptManager 界面冻结（真实复现过的卡死 bug）。
    public func launchApplication(at url: URL) {
        print("[ApplicationManager] Launching: \(url.path)")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error = error {
                print("[ApplicationManager] Launch error for \(url.path): \(error)")
            }
        }
    }
}