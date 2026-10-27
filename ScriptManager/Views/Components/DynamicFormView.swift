// ScriptManager/Views/Components/DynamicFormView.swift
import SwiftUI
import AppKit

/// 独立的动态表单渲染组件 (架构重构：彻底组件化，消除臃肿的 if-else)
public struct DynamicFormView: View {
    @ObservedObject var viewModel: ScriptDetailViewModel
    let parameters:[ScriptParameter]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(parameters) { param in
                FormRowContainer(param: param) {
                    ControlViewFactory.makeControl(for: param, viewModel: viewModel)
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

// MARK: - Form Row Container
/// 表单行容器，负责渲染左侧的 Label 和描述，右侧注入具体的 Control
struct FormRowContainer<Content: View>: View {
    let param: ScriptParameter
    let content: Content
    
    init(param: ScriptParameter, @ViewBuilder content: () -> Content) {
        self.param = param
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 左侧 Label 区域
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text(param.name)
                        .fontWeight(.medium)
                    if param.isRequired {
                        Text(Constants.UI.requiredMark)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                }
                Text(param.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 160, alignment: .leading)
            .padding(.top, 4)
            
            // 右侧 Control 区域
            VStack(alignment: .leading) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Control Factory
/// 控件工厂，根据参数类型分发到具体的视图组件
struct ControlViewFactory {
    @ViewBuilder
    static func makeControl(for param: ScriptParameter, viewModel: ScriptDetailViewModel) -> some View {
        switch param.type {
        case .bool:
            BoolInputControl(param: param, viewModel: viewModel)
        case .choice:
            ChoiceInputControl(param: param, viewModel: viewModel)
        case .path:
            PathInputControl(param: param, viewModel: viewModel)
        case .string:
            StringInputControl(param: param, viewModel: viewModel)
        }
    }
}

// MARK: - Specific Controls
struct BoolInputControl: View {
    let param: ScriptParameter
    @ObservedObject var viewModel: ScriptDetailViewModel
    
    var body: some View {
        Toggle("", isOn: Binding(
            get: { viewModel.boolValues[param.name] ?? false },
            set: { viewModel.boolValues[param.name] = $0 }
        ))
        .toggleStyle(.switch)
        .padding(.top, 2)
    }
}

struct ChoiceInputControl: View {
    let param: ScriptParameter
    @ObservedObject var viewModel: ScriptDetailViewModel
    
    var body: some View {
        if let options = param.options {
            Picker("", selection: Binding(
                get: { viewModel.stringValues[param.name] ?? "" },
                set: { viewModel.stringValues[param.name] = $0 }
            )) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300)
        }
    }
}

struct StringInputControl: View {
    let param: ScriptParameter
    @ObservedObject var viewModel: ScriptDetailViewModel
    
    // 架构级防坑：引入本地状态，防止用户粘贴参数后直接点击 Run 导致参数丢失
    @State private var localText: String = ""
    
    var body: some View {
        TextField("\(Constants.UI.pleaseInput) \(param.name)", text: $localText)
            .textFieldStyle(.roundedBorder)
            .onChange(of: localText) { _, newValue in
                viewModel.stringValues[param.name] = newValue
            }
            .onChange(of: viewModel.stringValues[param.name]) { _, newValue in
                let val = newValue ?? ""
                if localText != val {
                    localText = val
                }
            }
            .onAppear {
                localText = viewModel.stringValues[param.name] ?? ""
            }
    }
}

struct PathInputControl: View {
    let param: ScriptParameter
    @ObservedObject var viewModel: ScriptDetailViewModel
    
    // 架构级防坑：引入本地状态，防止用户粘贴参数后直接点击 Run 导致参数丢失
    @State private var localText: String = ""
    
    var body: some View {
        HStack {
            TextField("\(Constants.UI.pleaseInput) \(param.name)", text: $localText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: localText) { _, newValue in
                    viewModel.stringValues[param.name] = newValue
                }
                .onChange(of: viewModel.stringValues[param.name]) { _, newValue in
                    let val = newValue ?? ""
                    if localText != val {
                        localText = val
                    }
                }
                .onAppear {
                    localText = viewModel.stringValues[param.name] ?? ""
                }
            
            Button(Constants.UI.selectFileButton) {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                if panel.runModal() == .OK, let url = panel.url {
                    viewModel.stringValues[param.name] = url.path
                    localText = url.path
                }
            }
        }
    }
}