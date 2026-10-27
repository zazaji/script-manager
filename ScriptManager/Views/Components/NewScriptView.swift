// ScriptManager/Views/Components/NewScriptView.swift
import SwiftUI

enum ScriptTemplateOption: Hashable {
    case blank
    case defaultTemplate
    case sample(name: String, ext: String)
    
    var displayName: String {
        switch self {
        case .blank: return Constants.UI.blankScript
        case .defaultTemplate: return Constants.UI.defaultTemplate
        case .sample(let name, _): return "Sample: \(name)"
        }
    }
}

/// 独立的新建脚本表单组件，支持动态选择模板和示例
public struct NewScriptView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var workspaceVM: WorkspaceViewModel
    
    @State private var scriptName: String = ""
    @State private var selectedType: ScriptType = .bash
    @State private var selectedTemplate: ScriptTemplateOption = .defaultTemplate
    
    let availableTypes: [ScriptType] = [.bash, .python, .node, .ruby]
    
    var availableTemplates: [ScriptTemplateOption] {
        var templates: [ScriptTemplateOption] = [.defaultTemplate, .blank]
        for sample in SampleScriptsProvider.availableSamples where sample.ext == selectedType.rawValue {
            templates.append(.sample(name: sample.name, ext: sample.ext))
        }
        return templates
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text(Constants.UI.newScriptTitle)
                .font(.headline)
            
            Form {
                TextField(Constants.UI.scriptNamePlaceholder, text: $scriptName)
                    .textFieldStyle(.roundedBorder)
                
                Picker(Constants.UI.scriptTypeLabel, selection: $selectedType) {
                    ForEach(availableTypes, id: \.self) { type in
                        Text(type.rawValue.uppercased()).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedType) { _, _ in
                    selectedTemplate = .defaultTemplate
                }
                
                Picker(Constants.UI.templateOrSampleLabel, selection: $selectedTemplate) {
                    ForEach(availableTemplates, id: \.self) { template in
                        Text(template.displayName).tag(template)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()
            
            HStack {
                Button(Constants.UI.cancelButton) {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(Constants.UI.createButton) {
                    let content = contentToCreate
                    workspaceVM.createNewScript(name: scriptName, type: selectedType, content: content)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(scriptName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    /// 架构级防坑：通过 SampleScriptsProvider 动态获取内容
    var contentToCreate: String {
        switch selectedTemplate {
        case .blank:
            return ""
        case .defaultTemplate:
            return selectedType.defaultTemplate
        case .sample(let name, let ext):
            if let content = SampleScriptsProvider.getSampleContent(name: name, ext: ext) {
                return content
            }
            return selectedType.defaultTemplate
        }
    }
}