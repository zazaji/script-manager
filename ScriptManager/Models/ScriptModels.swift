// ScriptManager/Models/ScriptModels.swift
import Foundation
import SwiftUI
import Combine

/// 视图显示模式
public enum ViewMode: String, CaseIterable {
    case list
    case grid
    
    public var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

/// 脚本运行状态
public enum ScriptState {
    case idle
    case running
    case success
    case failure
}

/// 脚本类型
public enum ScriptType: String, CaseIterable {
    case bash = "sh"
    case python = "py"
    case node = "js"
    case ruby = "rb"
    case unknown = "unknown"
    
    public var iconName: String {
        switch self {
        case .python: return "curlybraces.square.fill"
        case .node: return "hexagon.fill"
        case .ruby: return "diamond.fill"
        case .bash: return "terminal.fill"
        case .unknown: return "doc.fill"
        }
    }
    
    public var iconColor: Color {
        switch self {
        case .python: return .blue
        case .node: return .yellow
        case .ruby: return .red
        case .bash: return .green
        case .unknown: return .gray
        }
    }
    
    public var defaultTemplate: String {
        switch self {
        case .bash: return "#!/bin/bash\n# @Name: New Bash Script\n# @Desc: Description\n# @Author: You\n# @Version: 1.0.0\n\necho \"Hello World\"\n"
        case .python: return "#!/usr/bin/env python3\n# @Name: New Python Script\n# @Desc: Description\n# @Author: You\n# @Version: 1.0.0\n\nprint(\"Hello World\")\n"
        case .node: return "#!/usr/bin/env node\n// @Name: New Node Script\n// @Desc: Description\n// @Author: You\n// @Version: 1.0.0\n\nconsole.log(\"Hello World\");\n"
        case .ruby: return "#!/usr/bin/env ruby\n# @Name: New Ruby Script\n# @Desc: Description\n# @Author: You\n# @Version: 1.0.0\n\nputs \"Hello World\"\n"
        case .unknown: return ""
        }
    }
}

/// 脚本物理文件实体
public struct ScriptItem: Identifiable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let type: ScriptType
    public var displayName: String?
    public var scriptDescription: String?
    public var parametersHint: String?
    
    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        self.type = ScriptType(rawValue: ext) ?? .unknown
        
        let meta = Self.extractMetadata(from: url)
        self.displayName = meta.name
        self.scriptDescription = meta.desc
        self.parametersHint = meta.params
    }
    
    private static func extractMetadata(from url: URL) -> (name: String?, desc: String?, params: String?) {
        var extractedName: String?
        var extractedDesc: String?
        var params: [String] = []
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            if let data = try fileHandle.read(upToCount: 4096),
               let content = String(data: data, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    if index >= 50 { break }
                    
                    if let range = line.range(of: "@Name:") {
                        extractedName = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    } else if let range = line.range(of: "@Desc:") {
                        extractedDesc = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    } else if let range = line.range(of: "@Param:") {
                        let paramStr = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                        let parts = paramStr.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                        if parts.count >= 3 {
                            let name = parts[0]
                            let requiredStr = parts[2].lowercased()
                            let required = (requiredStr == "true" || requiredStr == "1" || requiredStr == "yes")
                            if required {
                                params.append("<\(name)>")
                            } else {
                                params.append("[\(name)]")
                            }
                        } else if parts.count >= 1 {
                            params.append("[\(parts[0])]")
                        }
                    }
                }
            }
        } catch {
            // 静默失败
        }
        let paramsStr = params.isEmpty ? nil : params.joined(separator: " ")
        return (extractedName, extractedDesc, paramsStr)
    }
}

/// 架构级重构：移除沉重的 NSImage，仅保留轻量级元数据，实现毫秒级扫描
public struct ApplicationItem: Identifiable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    
    public init(url: URL, name: String) {
        self.url = url
        self.name = name
    }
}

public enum ParameterType: String {
    case string = "string"
    case bool = "bool"
    case path = "path"
    case choice = "choice"
}

public struct ScriptParameter: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let type: ParameterType
    public let description: String
    public let isRequired: Bool
    public let defaultValue: String?
    public let options: [String]?
    
    public init(name: String, type: ParameterType, description: String, isRequired: Bool, defaultValue: String?, options: [String]? = nil) {
        self.name = name
        self.type = type
        self.description = description
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.options = options
    }
}

public struct ScriptEnvironmentVariable: Identifiable, Hashable, Codable {
    public var id = UUID()
    public var name: String
    public var value: String
    
    public init(name: String = "", value: String = "") {
        self.name = name
        self.value = value
    }
}

public struct ScriptMetadata {
    public var name: String = ""
    public var description: String = Constants.UI.noDescription
    public var author: String? = nil
    public var version: String? = nil
    public var parameters: [ScriptParameter] = []
    public var example: String = Constants.UI.noExample
    
    public init() {}
}

public enum LogType {
    case info
    case output
    case error
}

public protocol ExecutionTaskProtocol: AnyObject {
    func cancel()
    func sendInput(_ text: String)
}

@MainActor
public class ExecutionSession: Identifiable, ObservableObject {
    public let id = UUID()
    public let scriptName: String
    
    @Published public var attributedLogs: NSAttributedString = NSAttributedString()
    private var internalLogs = NSMutableAttributedString()
    
    // 架构级增强：暴露最新一行日志，供悬浮窗实时滚动显示
    @Published public var latestLogLine: String = ""
    
    @Published public var state: ScriptState = .idle
    public var task: ExecutionTaskProtocol?
    
    public var tempFileURL: URL?
    
    public init(scriptName: String) {
        self.scriptName = scriptName
    }
    
    public func appendLog(_ text: String, type: LogType) {
        let color: NSColor
        switch type {
        case .info: color = .systemGray
        case .output: color = .systemGreen
        case .error: color = .systemRed
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        let formattedText = type == .info ? text + "\n" : text
        let attrString = NSAttributedString(string: formattedText, attributes: attributes)
        internalLogs.append(attrString)
        
        if internalLogs.length > 100000 {
            internalLogs.deleteCharacters(in: NSRange(location: 0, length: internalLogs.length - 100000))
        }
        
        attributedLogs = NSAttributedString(attributedString: internalLogs)
        
        // 提取最后一行非空日志，更新悬浮窗状态
        let lines = text.components(separatedBy: .newlines)
        if let lastLine = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            latestLogLine = lastLine
        }
    }
    
    public func clearLogs() {
        internalLogs = NSMutableAttributedString()
        attributedLogs = NSAttributedString()
        latestLogLine = ""
    }
    
    public func sendInput(_ text: String) {
        task?.sendInput(text)
    }
    
    public func stop() {
        task?.cancel()
        task = nil
        state = .idle
        appendLog(Constants.UI.processTerminatedByUser, type: .error)
        cleanupTempFile()
    }
    
    public func cleanupTempFile() {
        if let url = tempFileURL {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    print("[ExecutionSession] Garbage Collection: Cleaned up temp file at \(url.path)")
                }
            } catch {
                print("[ExecutionSession] Failed to clean up temp file: \(error)")
            }
            tempFileURL = nil
        }
    }
}

/// 架构级增强：AI Agent API 类型，支持不同厂商的请求格式
public enum AIAgentType: String, Codable, CaseIterable {
    case openAI = "OpenAI Compatible"
    case anthropic = "Anthropic"
    case openClaw = "OpenClaw"
}

/// 架构级增强：动态 AI Agent 配置模型，支持无限扩展与专属快捷键
public struct AIAgentConfiguration: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var type: AIAgentType
    public var endpoint: String
    public var apiKey: String
    public var prefix: String
    public var themeColor: String
    
    // 专属全局快捷键
    public var hotkeyCode: UInt16 = 0
    public var hotkeyModifiers: UInt32 = 0
    
    public init(id: UUID = UUID(), name: String, type: AIAgentType, endpoint: String, apiKey: String = "", prefix: String, themeColor: String = "blue", hotkeyCode: UInt16 = 0, hotkeyModifiers: UInt32 = 0) {
        self.id = id
        self.name = name
        self.type = type
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.prefix = prefix
        self.themeColor = themeColor
        self.hotkeyCode = hotkeyCode
        self.hotkeyModifiers = hotkeyModifiers
    }
    
    public var uiColor: Color {
        switch themeColor {
        case "purple": return .purple
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "gray": return .gray
        default: return .accentColor
        }
    }
    
    public var icon: String {
        switch themeColor {
        case "purple": return "sparkles"
        case "blue": return "chevron.left.forwardslash.chevron.right"
        case "orange": return "ant.fill"
        case "green": return "leaf.fill"
        case "red": return "flame.fill"
        case "gray": return "cpu"
        default: return "cpu"
        }
    }
}