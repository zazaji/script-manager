// ScriptManager/Services/WorkspaceManager.swift
import Foundation
import Combine

/// 架构级增强：示例脚本内容提供者，直接硬编码提供高质量示例，消除文件读取依赖
public struct SampleScriptsProvider {
    public static let samples:[(name: String, ext: String, content: String)] = [
        ("find_largest_files", "sh", """
        #!/bin/bash
        # @Name: Find Largest Files
        # @Desc: Find the largest files in a directory
        # @Author: ScriptManager
        # @Version: 1.0.0
        # @Param: dir | path | true | / | Directory to search
        # @Param: count | string | true | 10 | Number of files to show
        
        DIR=$1
        COUNT=$2
        echo "🔍 Searching for top $COUNT largest files in $DIR..."
        find "$DIR" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -n "$COUNT"
        """),
        ("openai_chat", "py", """
        #!/usr/bin/env python3
        # @Name: OpenAI Chat
        # @Desc: Chat with OpenAI GPT model
        # @Author: ScriptManager
        # @Version: 1.0.0
        # @Param: prompt | string | true | Hello | The prompt to send
        # @Param: model | choice | true | gpt-3.5-turbo | Model to use | gpt-3.5-turbo, gpt-4
        
        import sys
        import os
        import urllib.request
        import json
        
        def main():
            if len(sys.argv) < 3:
                print("Usage: script.py <prompt> <model>")
                sys.exit(1)
                
            prompt = sys.argv[1]
            model = sys.argv[2]
            api_key = os.environ.get("OPENAI_API_KEY")
            
            if not api_key:
                print("❌ Error: OPENAI_API_KEY environment variable is not set.")
                sys.exit(1)
                
            print(f"🤖 Sending request to OpenAI ({model})...")
            
            url = "https://api.openai.com/v1/chat/completions"
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}"
            }
            data = {
                "model": model,
                "messages":[{"role": "user", "content": prompt}]
            }
            
            req = urllib.request.Request(url, data=json.dumps(data).encode("utf-8"), headers=headers)
            try:
                with urllib.request.urlopen(req) as response:
                    result = json.loads(response.read().decode("utf-8"))
                    print("\\n💬 Response:")
                    print(result["choices"][0]["message"]["content"])
            except Exception as e:
                print(f"❌ Request failed: {e}")
                
        if __name__ == "__main__":
            main()
        """),
        ("api_tester", "js", """
        #!/usr/bin/env node
        // @Name: REST API Tester
        // @Desc: Automated API testing utility
        // @Author: ScriptManager
        // @Version: 1.5.0
        // @Param: endpoint | string | true | https://jsonplaceholder.typicode.com/todos/1 | API Endpoint URL
        // @Param: method | choice | true | GET | HTTP Method | GET, POST, PUT, DELETE
        
        const https = require('https');
        const args = process.argv.slice(2);
        const endpoint = args[0] || "https://jsonplaceholder.typicode.com/todos/1";
        const method = args[1] || "GET";
        
        console.log(`📡 Sending ${method} request to ${endpoint}...`);
        
        const req = https.request(endpoint, { method: method }, (res) => {
            console.log(`\\n📥 Status Code: ${res.statusCode}`);
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                console.log("📦 Response Data:");
                console.log(data);
            });
        });
        req.on('error', (e) => console.error(`❌ Error: ${e.message}`));
        req.end();
        """),
        ("data_processor", "rb", """
        #!/usr/bin/env ruby
        # @Name: Data Processor
        # @Desc: Process data files
        # @Author: ScriptManager
        # @Version: 1.0.0
        # @Param: input | path | true | | Input file path
        # @Param: upcase | bool | false | false | Convert to uppercase
        
        input_file = ARGV[0]
        upcase = ARGV.include?("--upcase")
        
        if input_file.nil? || input_file.empty?
          puts "❌ Error: Input file is required"
          exit 1
        end
        
        puts "🔧 Processing #{input_file}..."
        begin
          content = File.read(input_file)
          content = content.upcase if upcase
          puts "✅ Output:"
          puts content[0..100] + (content.length > 100 ? "..." : "")
        rescue => e
          puts "❌ Failed to read file: #{e.message}"
        end
        """)
    ]
    
    public static var availableSamples: [(name: String, ext: String)] {
        return samples.map { ($0.name, $0.ext) }.sorted { $0.name < $1.name }
    }
    
    public static func getSampleContent(name: String, ext: String) -> String? {
        return samples.first { $0.name == name && $0.ext == ext }?.content
    }
}

/// 工作区文件系统监听服务
public class WorkspaceManager {
    public static let shared = WorkspaceManager()
    private var folderMonitorSource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.scriptmanager.workspaceMonitor")
    
    public let workspaceChanged = PassthroughSubject<Void, Never>()
    
    private init() {}
    
    public func startMonitoring(url: URL) {
        stopMonitoring()
        
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else {
            print("[WorkspaceManager] Failed to open directory for monitoring: \(url.path)")
            return
        }
        
        folderMonitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: queue)
        
        folderMonitorSource?.setEventHandler {[weak self] in
            DispatchQueue.main.async {
                self?.workspaceChanged.send()
            }
        }
        
        folderMonitorSource?.setCancelHandler {
            close(descriptor)
        }
        
        folderMonitorSource?.resume()
        print("[WorkspaceManager] Started monitoring: \(url.path)")
    }
    
    public func stopMonitoring() {
        if let source = folderMonitorSource {
            source.cancel()
            folderMonitorSource = nil
            print("[WorkspaceManager] Stopped monitoring.")
        }
    }
    
    public func createScript(at workspaceURL: URL, name: String, type: ScriptType, content: String? = nil) throws -> URL {
        let fileName = name.hasSuffix(".\(type.rawValue)") ? name : "\(name).\(type.rawValue)"
        let fileURL = workspaceURL.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            throw NSError(domain: "WorkspaceManager", code: 1, userInfo:[NSLocalizedDescriptionKey: "File already exists"])
        }
        
        let finalContent = content ?? type.defaultTemplate
        try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let currentPosixPermissions = attributes[.posixPermissions] as? NSNumber ?? NSNumber(value: 0o644)
        let newPosixPermissions = currentPosixPermissions.intValue | 0o111 // Add execute bit
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: newPosixPermissions)], ofItemAtPath: fileURL.path)
        
        print("[WorkspaceManager] Successfully created script with +x permission at: \(fileURL.path)")
        return fileURL
    }
    
    /// 架构级增强：直接将硬编码的高质量示例脚本写入工作区，并自动赋予执行权限
    public func createSampleScripts(at workspaceURL: URL) throws {
        for sample in SampleScriptsProvider.samples {
            let fileName = "\(sample.name).\(sample.ext)"
            let destURL = workspaceURL.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: destURL.path) {
                do {
                    try sample.content.write(to: destURL, atomically: true, encoding: .utf8)
                    let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
                    let currentPosixPermissions = attributes[.posixPermissions] as? NSNumber ?? NSNumber(value: 0o644)
                    let newPosixPermissions = currentPosixPermissions.intValue | 0o111 // Add execute bit
                    try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: newPosixPermissions)], ofItemAtPath: destURL.path)
                    print("[WorkspaceManager] Created sample script: \(destURL.path)")
                } catch {
                    print("[WorkspaceManager] Failed to create sample script \(fileName): \(error)")
                }
            }
        }
    }
    
    /// 读取脚本内容
    public func readScript(url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    /// 保存脚本内容
    public func saveScript(url: URL, content: String) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
        print("[WorkspaceManager] Successfully saved script at: \(url.path)")
    }
}