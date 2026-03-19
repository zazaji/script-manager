// ScriptManager/Core/PinyinHelper.swift
import Foundation

public struct PinyinHelper {
    /// 将字符串转换为拼音（全拼和首字母简拼）
    /// 例如："你好" -> "nihao" 和 "nh"
    public static func getSearchFeatures(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        
        var features = [trimmed.lowercased()]
        
        // 1. 转换为带音标的拼音
        let mutableString = NSMutableString(string: trimmed) as CFMutableString
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        
        // 2. 去掉音标
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        
        let fullPinyin = (mutableString as String).lowercased()
        // 去掉拼音间的空格
        let flattenedPinyin = fullPinyin.replacingOccurrences(of: " ", with: "")
        features.append(flattenedPinyin)
        
        // 3. 提取首字母简拼
        let initials = fullPinyin.components(separatedBy: " ")
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
        features.append(initials)
        
        return features
    }
    
    /// 检查文本是否匹配搜索关键字（支持汉字、全拼、简拼）
    public static func isMatch(text: String, searchText: String) -> Bool {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return true }
        
        let features = getSearchFeatures(from: text)
        return features.contains { $0.contains(query) }
    }
}