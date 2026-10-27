// ScriptManager/Views/Components/ApplicationDetailView.swift
import SwiftUI
import AppKit

/// 架构级增强：应用详情视图，展示应用元数据并提供打开入口
public struct ApplicationDetailView: View {
    let app: ApplicationItem
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部 Header：展示核心信息与操作
            HStack(spacing: 24) {
                // 架构级修复：使用异步 AppIconView 替代同步加载
                AppIconView(url: app.url)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(app.name)
                        .font(.system(size: 32, weight: .bold))
                    
                    Text(Constants.UI.appInfoTitle)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    ApplicationManager.shared.launchApplication(at: app.url)
                }) {
                    HStack {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text(Constants.UI.openAppButton)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(40)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 详情内容区
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // 路径信息
                    InfoSection(title: Constants.UI.appPathLabel) {
                        HStack {
                            Text(app.url.path)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            Button(action: {
                                NSWorkspace.shared.selectFile(
                                    app.url.path, 
                                    inFileViewerRootedAtPath: ""
                                )
                            }) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help(Constants.UI.openInFinderButton)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    }
                    
                    // 扩展元数据
                    if let bundle = Bundle(url: app.url) {
                        HStack(spacing: 40) {
                            InfoSection(title: Constants.UI.versionLabel) {
                                Text(bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                            
                            InfoSection(title: "Bundle ID") {
                                Text(bundle.bundleIdentifier ?? "Unknown")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

/// 内部复用的信息区块组件
struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
        }
    }
}