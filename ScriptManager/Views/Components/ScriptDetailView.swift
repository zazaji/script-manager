// ScriptManager/Views/Components/ScriptDetailView.swift
import SwiftUI

/// 详情页容器视图，支持在“参数配置”、“代码编辑”和“分屏模式”之间切换
public struct ScriptDetailView: View {
    @ObservedObject var viewModel: ScriptDetailViewModel
    let item: ScriptItem
    
    // 默认进入分屏模式(2)，最大化展示核心卖点
    @State private var selectedTab = 2 
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部紧凑 Header
            ScriptHeaderView(viewModel: viewModel, item: item, selectedTab: $selectedTab)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 2. 内容区：根据模式动态渲染
            if selectedTab == 0 {
                configPanelView
            } else if selectedTab == 1 {
                codePanelView
            } else {
                // 架构级重构：彻底抛弃存在底层溢出 Bug 的 HSplitView。
                // HSplitView 在 NavigationSplitView 的 detail 区域中会忽略安全边界向左反向溢出，导致被 Sidebar 遮挡。
                // 现改用原生的 HStack 结合均分策略，确保双栏严格对齐顶部 Header，且绝不越过 Sidebar 边界。
                HStack(spacing: 0) {
                    configPanelView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Divider()
                        .background(Color(NSColor.separatorColor))
                    
                    codePanelView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(item.name)
    }
    
    // MARK: - Subviews
    
    /// 参数配置面板
    private var configPanelView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 顶部显示元数据
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.metadata?.name ?? item.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let desc = viewModel.metadata?.description, desc != Constants.UI.noDescription {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        if let author = viewModel.metadata?.author, !author.isEmpty {
                            Label(author, systemImage: "person.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let version = viewModel.metadata?.version, !version.isEmpty {
                            Label("v\(version)", systemImage: "tag.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 8)
                
                // 动态参数表单
                if let meta = viewModel.metadata, !meta.parameters.isEmpty {
                    Text(Constants.UI.parametersTitle)
                        .font(.headline)
                    DynamicFormView(viewModel: viewModel, parameters: meta.parameters)
                } else {
                    Text(Constants.UI.noParametersRequired)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // 环境变量配置区域
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(Constants.UI.environmentVariablesTitle)
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            viewModel.environmentVariables.append(ScriptEnvironmentVariable())
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(Constants.UI.addEnvVarButton)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    
                    if viewModel.environmentVariables.isEmpty {
                        Text(Constants.UI.noEnvVarsConfigured)
                            .foregroundColor(.secondary)
                            .italic()
                            .font(.caption)
                    } else {
                        VStack(spacing: 8) {
                            ForEach($viewModel.environmentVariables) { $envVar in
                                HStack {
                                    TextField(Constants.UI.envVarNamePlaceholder, text: $envVar.name)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 150)
                                    
                                    Text("=")
                                        .foregroundColor(.secondary)
                                    
                                    TextField(Constants.UI.envVarValuePlaceholder, text: $envVar.value)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: {
                                        viewModel.environmentVariables.removeAll { $0.id == envVar.id }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    }
                }
                
                if let example = viewModel.metadata?.example, !example.isEmpty, example != Constants.UI.noExample {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Constants.UI.exampleLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(example)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(24)
            // 强制内部内容对其左边界，确保不会由于弹性布局居中而产生意外的偏移裁切
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.textBackgroundColor))
        // 架构级修复：移除原来用来制衡 HSplitView 的刚性 minWidth，让 SwiftUI 可以完美接管弹性布局
    }
    
    /// 代码编辑面板
    private var codePanelView: some View {
        CodeEditorView(text: $viewModel.scriptContent, language: item.type, onSave: {
            viewModel.saveScript()
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}