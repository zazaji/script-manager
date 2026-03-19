// ScriptManager/Services/ScriptExecutionService.swift
import Foundation
import Darwin

/// 脚本执行任务句柄，实现交互式输入与生命周期控制
public class ScriptExecutionTask: ExecutionTaskProtocol {
    private let process: Process
    private let masterHandle: FileHandle?
    private let stdinPipe: Pipe?
    public let id = UUID()
    
    init(process: Process, masterHandle: FileHandle?, stdinPipe: Pipe?) {
        self.process = process
        self.masterHandle = masterHandle
        self.stdinPipe = stdinPipe
    }
    
    public func cancel() {
        if process.isRunning {
            process.terminate()
            print("[ExecutionTask] Process \(process.processIdentifier) terminated by user.")
        }
    }
    
    public func sendInput(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else { return }
        do {
            if let master = masterHandle {
                try master.write(contentsOf: data)
                print("[ExecutionTask] Sent input to PTY: \(text)")
            } else if let pipe = stdinPipe {
                try pipe.fileHandleForWriting.write(contentsOf: data)
                print("[ExecutionTask] Sent input to Pipe: \(text)")
            }
        } catch {
            print("[ExecutionTask] Failed to send input: \(error)")
        }
    }
}

public class ScriptExecutionService {
    public static let shared = ScriptExecutionService()
    private init() {}
    
    /// 异步执行脚本，支持 PTY 伪终端分配，确保 sudo 等交互式命令正常工作
    public func execute(item: ScriptItem, arguments: [String], environmentVariables: [ScriptEnvironmentVariable], session: ExecutionSession) throws -> ScriptExecutionTask {
        let process = Process()
        
        var masterHandle: FileHandle?
        var slaveHandle: FileHandle?
        var stdinPipe: Pipe?
        var stdoutPipe: Pipe?
        var stderrPipe: Pipe?
        
        // 1. 强化 PTY 分配逻辑，确保 sudo 识别为终端
        let masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        if masterFD != -1 {
            if grantpt(masterFD) == 0 && unlockpt(masterFD) == 0 {
                if let slavePathPtr = ptsname(masterFD) {
                    let slaveFD = open(slavePathPtr, O_RDWR | O_NOCTTY)
                    if slaveFD != -1 {
                        masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
                        slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
                        
                        // 关键：将 Slave FD 分配给所有标准流，模拟真实终端环境
                        process.standardInput = slaveHandle
                        process.standardOutput = slaveHandle
                        process.standardError = slaveHandle
                    } else {
                        close(masterFD)
                    }
                } else {
                    close(masterFD)
                }
            } else {
                close(masterFD)
            }
        }
        
        // 2. 降级方案：如果 PTY 分配失败，使用普通 Pipe
        if masterHandle == nil {
            print("[ExecutionService] ⚠️ PTY allocation failed, falling back to Pipes.")
            stdinPipe = Pipe()
            stdoutPipe = Pipe()
            stderrPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
        }
        
        // 3. 赋予执行权限
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: item.url.path)
        
        let appState = AppStateManager.shared
        let envPath = appState.envPath.trimmingCharacters(in: .whitespaces).isEmpty ? "~/.bash_profile" : appState.envPath
        
        let wrapperScript = """
        if [ -f ~/.bash_profile ]; then source ~/.bash_profile >/dev/null 2>&1; fi
        if [ -f ~/.zshrc ]; then source ~/.zshrc >/dev/null 2>&1; fi
        if [ -f "\(envPath)" ]; then source "\(envPath)" >/dev/null 2>&1; fi
        exec "$@"
        """
        
        let shellExec = appState.defaultShell == "zsh" ? "/bin/zsh" : "/bin/bash"
        process.executableURL = URL(fileURLWithPath: shellExec)
        
        let pythonExec = appState.pythonPath.trimmingCharacters(in: .whitespaces).isEmpty ? "python3" : appState.pythonPath
        let nodeExec = appState.nodePath.trimmingCharacters(in: .whitespaces).isEmpty ? "node" : appState.nodePath
        let rubyExec = appState.rubyPath.trimmingCharacters(in: .whitespaces).isEmpty ? "ruby" : appState.rubyPath
        
        var actualArgs: [String] = []
        switch item.type {
        case .python:
            actualArgs = [pythonExec, "-u", item.url.path] + arguments
        case .node:
            actualArgs = [nodeExec, item.url.path] + arguments
        case .ruby:
            actualArgs = [rubyExec, item.url.path] + arguments
        case .bash:
            actualArgs = ["bash", item.url.path] + arguments
        case .unknown:
            actualArgs = [item.url.path] + arguments
        }
        
        process.arguments = ["-c", wrapperScript, "--"] + actualArgs
        
        // 4. 注入环境变量，TERM 是 sudo 成功的关键
        var environment = ProcessInfo.processInfo.environment
        let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(defaultPath):\(environment["PATH"] ?? "")"
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        
        // 必须设置 TERM 环境变量，否则 sudo 可能拒绝在 PTY 中运行
        if masterHandle != nil {
            environment["TERM"] = "xterm-256color"
        }
        
        for envVar in environmentVariables {
            if !envVar.name.isEmpty { environment[envVar.name] = envVar.value }
        }
        process.environment = environment
        
        let task = ScriptExecutionTask(process: process, masterHandle: masterHandle, stdinPipe: stdinPipe)
        
        process.terminationHandler = { p in
            let status = p.terminationStatus
            Task { @MainActor in
                session.state = status == 0 ? .success : .failure
                if status == 0 {
                    session.appendLog(Constants.UI.processFinishedSuccess, type: .info)
                } else {
                    session.appendLog(Constants.UI.processFinishedFailure(String(status)), type: .error)
                }
                session.task = nil
            }
            masterHandle?.readabilityHandler = nil
            stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            stderrPipe?.fileHandleForReading.readabilityHandler = nil
            try? masterHandle?.close()
            try? slaveHandle?.close()
        }
        
        do {
            try process.run()
            // 启动后立即关闭父进程中的 slave 句柄，这是 PTY 规范
            try? slaveHandle?.close()
        } catch {
            print("[Execution Error]: \(error)")
            throw error
        }
        
        // 5. 读取输出并清理 ANSI 字符
        if let handle = masterHandle {
            handle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                if let string = String(data: data, encoding: .utf8) {
                    let cleanString = string.strippingANSI()
                    Task { @MainActor in session.appendLog(cleanString, type: .output) }
                }
            }
        } else {
            stdoutPipe?.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                if let string = String(data: data, encoding: .utf8) {
                    let cleanString = string.strippingANSI()
                    Task { @MainActor in session.appendLog(cleanString, type: .output) }
                }
            }
            stderrPipe?.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                if let string = String(data: data, encoding: .utf8) {
                    let cleanString = string.strippingANSI()
                    Task { @MainActor in session.appendLog(cleanString, type: .error) }
                }
            }
        }
        
        return task
    }
}

// 架构级修复：显式定义 String 扩展，解决 strippingANSI 编译错误
extension String {
    func strippingANSI() -> String {
        let pattern = "\u{001B}\\[[0-9;]*[a-zA-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return self }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
    }
}