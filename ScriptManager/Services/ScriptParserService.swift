// ScriptManager/Services/ScriptParserService.swift
import Foundation

public class ScriptParserService {
    public static let shared = ScriptParserService()
    private init() {}
    
    /// 异步流式解析脚本头部注释
    /// - Parameter url: 脚本文件路径
    /// - Returns: 解析后的元数据模型
    public func parse(url: URL) async throws -> ScriptMetadata {
        print("========== PARSER SERVICE ==========")
        print("[Parsing File]: \(url.path)")
        
        var metadata = ScriptMetadata()
        // 默认使用文件名，消除 Unnamed Script
        metadata.name = url.lastPathComponent
        
        var lineCount = 0
        let maxLinesToRead = 100 // 架构防坑：防止读取超大文件导致内存溢出
        
        do {
            for try await line in url.lines {
                lineCount += 1
                if lineCount > maxLinesToRead {
                    print("[Parser] Reached max lines (\(maxLinesToRead)), stopping parse.")
                    break
                }
                
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // 兼容 Bash (#), Python ( """ 或 # ), Node (// 或 /*) 的注释风格
                let isComment = trimmedLine.hasPrefix("#") || 
                                trimmedLine.hasPrefix("\"\"\"") || 
                                trimmedLine.hasPrefix("'''") ||
                                trimmedLine.hasPrefix("//") ||
                                trimmedLine.hasPrefix("/*") ||
                                trimmedLine.hasPrefix("*")
                
                if !trimmedLine.isEmpty && !isComment {
                    // 如果遇到非空行且不是注释，说明头部注释区已结束，提前退出
                    if lineCount > 15 { break }
                }
                
                parseLine(trimmedLine, into: &metadata)
            }
        } catch {
            print("[Parser Error]: Failed to read file lines. Error: \(error)")
            throw error
        }
        
        print("[Parser Success]: Parsed '\(metadata.name)' with \(metadata.parameters.count) parameters.")
        print("====================================")
        return metadata
    }
    
    /// 架构重构：将单行解析逻辑抽离，降低圈复杂度
    private func parseLine(_ line: String, into metadata: inout ScriptMetadata) {
        if let nameRange = line.range(of: "@Name:") {
            metadata.name = String(line[nameRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let descRange = line.range(of: "@Desc:") {
            metadata.description = String(line[descRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let authorRange = line.range(of: "@Author:") {
            metadata.author = String(line[authorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let versionRange = line.range(of: "@Version:") {
            metadata.version = String(line[versionRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let exampleRange = line.range(of: "@Example:") {
            metadata.example = String(line[exampleRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let paramRange = line.range(of: "@Param:") {
            parseParameter(from: String(line[paramRange.upperBound...]), into: &metadata)
        }
    }
    
    /// 架构重构：将参数解析逻辑抽离
    private func parseParameter(from string: String, into metadata: inout ScriptMetadata) {
        let paramString = string.trimmingCharacters(in: .whitespaces)
        let components = paramString.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // 契约格式: @Param: name | type | required | default | desc | options(可选,逗号分隔)
        if components.count >= 5 {
            let name = components[0]
            let typeStr = components[1].lowercased()
            let requiredStr = components[2].lowercased()
            let defaultVal = components[3]
            let desc = components[4]
            var options: [String]? = nil
            
            if components.count >= 6 {
                options = components[5].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            
            let type = ParameterType(rawValue: typeStr) ?? .string
            let isRequired = (requiredStr == "true" || requiredStr == "1" || requiredStr == "yes")
            
            let parameter = ScriptParameter(name: name, type: type, description: desc, isRequired: isRequired, defaultValue: defaultVal.isEmpty ? nil : defaultVal, options: options)
            metadata.parameters.append(parameter)
            print("[Parser] Found Parameter: \(name) | \(type.rawValue) | req:\(isRequired) | def:\(defaultVal) | \(desc)")
        } else if components.count >= 3 {
            // 兼容旧格式: @Param: name | type | desc
            let name = components[0]
            let typeStr = components[1].lowercased()
            let desc = components[2]
            let type = ParameterType(rawValue: typeStr) ?? .string
            
            let parameter = ScriptParameter(name: name, type: type, description: desc, isRequired: false, defaultValue: nil, options: nil)
            metadata.parameters.append(parameter)
            print("[Parser] Found Parameter (Legacy): \(name) | \(type.rawValue) | \(desc)")
        }
    }
}