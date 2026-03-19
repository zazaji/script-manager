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
    
    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        self.type = ScriptType(rawValue: ext) ?? .unknown
        
        let meta = Self.extractMetadata(from: url)
        self.displayName = meta.name
        self.scriptDescription = meta.desc
    }
    
    /// 架构级增强：同步提取元数据，用于搜索过滤
    private static func extractMetadata(from url: URL) -> (name: String?, desc: String?) {
        var extractedName: String?
        var extractedDesc: String?
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            // 只读取前 2048 字节，平衡性能与解析完整性
            if let data = try fileHandle.read(upToCount: 2048),
               let content = String(data: data, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    if index >= 30 { break } // 限制扫描行数
                    
                    if let range = line.range(of: "@Name:") {
                        extractedName = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    }
                    if let range = line.range(of: "@Desc:") {
                        extractedDesc = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    }
                    
                    if extractedName != nil && extractedDesc != nil { break }
                }
            }
        } catch {
            // 静默失败，不影响主流程
        }
        return (extractedName, extractedDesc)
    }
}

/// 架构级增强：系统应用实体
public struct ApplicationItem: Identifiable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let icon: NSImage
    
    public init(url: URL, name: String, icon: NSImage) {
        self.url = url
        self.name = name
        self.icon = icon
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
    
    @Published public var state: ScriptState = .idle
    public var task: ExecutionTaskProtocol?
    
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
    }
    
    public func clearLogs() {
        internalLogs = NSMutableAttributedString()
        attributedLogs = NSAttributedString()
    }
    
    public func sendInput(_ text: String) {
        task?.sendInput(text)
    }
    
    public func stop() {
        task?.cancel()
        task = nil
        state = .idle
        appendLog(Constants.UI.processTerminatedByUser, type: .error)
    }
}