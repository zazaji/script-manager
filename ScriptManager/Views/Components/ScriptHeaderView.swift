// ScriptManager/Views/Components/ScriptHeaderView.swift
import SwiftUI
import AppKit

/// 独立的脚本元数据展示组件，实现右上角紧凑布局
public struct ScriptHeaderView: View {
    @ObservedObject var viewModel: ScriptDetailViewModel
    let item: ScriptItem
    @Binding var selectedTab: Int
    @ObservedObject var appState = AppStateManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                // 左侧：脚本信息
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.metadata?.name ?? item.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // 架构级增强：收藏按钮
                        Button(action: {
                            appState.toggleFavorite(item.url.path)
                        }) {
                            Image(systemName: appState.isFavorite(item.url.path) ? "star.fill" : "star")
                                .foregroundColor(appState.isFavorite(item.url.path) ? .yellow : .gray)
                        }
                        .buttonStyle(.plain)
                        .help(appState.isFavorite(item.url.path) ? Constants.UI.removeFromFavorites : Constants.UI.addToFavorites)
                    }
                }
                
                Spacer()
                
                // 右侧：Tab 切换与文件操作，使用 fixedSize 避免重叠挤压
                HStack(spacing: 16) {
                    // 架构级增强：增加分屏模式选项，打造极致的所见即所得体验
                    Picker("", selection: $selectedTab) {
                        Text(Constants.UI.configurationTab).tag(0)
                        Text(Constants.UI.codeTab).tag(1)
                        Image(systemName: "rectangle.split.2x1").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // 架构级防坑：强制取消焦点，确保所有 TextField（如环境变量）提交数据
                            NSApp.keyWindow?.makeFirstResponder(nil)
                            DispatchQueue.main.async {
                                viewModel.saveScript()
                            }
                        }) {
                            Image(systemName: "externaldrive.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help(Constants.UI.saveButton)
                        
                        Button(action: {
                            NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
                        }) {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help(Constants.UI.openInFinderButton)
                    }
                }
            }
            
            // 下一行：运行参数与运行按钮，避免拥挤
            HStack(spacing: 12) {
                TextField(Constants.UI.additionalArgsPlaceholder, text: $viewModel.additionalArguments)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: {
                    // 架构级防坑：强制取消焦点，确保所有 TextField（如附加参数、环境变量）提交数据
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    DispatchQueue.main.async {
                        viewModel.runScript()
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(Constants.UI.runScriptButton)
                            .fontWeight(.bold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.regular)
            }
        }
    }
}