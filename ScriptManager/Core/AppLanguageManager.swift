// ScriptManager/Core/AppLanguageManager.swift
import Foundation
import SwiftUI
import Combine

/// 全局语言管理器，用于实现多语言的即时切换
public class AppLanguageManager: ObservableObject {
    public static let shared = AppLanguageManager()
    
    @Published public var currentLanguage: String {
        didSet {
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            // 架构级防坑：显式传入 userInfo: nil，消除 Swift 编译器的重载推断歧义
            NotificationCenter.default.post(name: .languageDidChange, object: nil, userInfo: nil)
        }
    }
    
    private init() {
        let langs = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? ["en"]
        let firstLang = langs.first ?? "en"
        self.currentLanguage = firstLang.hasPrefix("zh") ? "zh-Hans" : "en"
    }
    
    public func localizedString(forKey key: String, value: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, value: value, comment: "")
        }
        return bundle.localizedString(forKey: key, value: value, table: nil)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}