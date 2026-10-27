// ScriptManager/Core/PinyinHelper.swift
import Foundation

public struct PinyinHelper {
    /// 特征串缓存：脚本名/应用名是稳定集合，但会在搜索的每次击键中被反复查询，
    /// CFStringTransform 开销不小，缓存后每个文本只付一次转换成本。
    /// 调用方（filterItems）均在主线程，普通字典即安全；超限整表清空防极端增长。
    private static var cache: [String: [String]] = [:]
    private static let cacheLimit = 4096

    /// 将字符串转换为拼音（全拼和首字母简拼）
    /// 例如："你好" -> "nihao" 和 "nh"
    public static func getSearchFeatures(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        if let cached = cache[trimmed] { return cached }

        var features = [trimmed.lowercased()]

        // 架构级防坑：纯 ASCII 且不含空格时转换是恒等操作，三个特征完全相同，直接跳过；
        // 含空格的 ASCII 仍要走转换，否则首字母简拼（如 "Big Buck Bunny" -> "bbb"）会丢失
        if !isASCIIOnly(trimmed) || trimmed.contains(" ") {
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
        }

        if cache.count >= cacheLimit { cache.removeAll(keepingCapacity: true) }
        cache[trimmed] = features
        return features
    }

    /// 检查文本是否匹配搜索关键字（支持汉字、全拼、简拼）
    public static func isMatch(text: String, searchText: String) -> Bool {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return true }

        let features = getSearchFeatures(from: text)
        return features.contains { $0.contains(query) }
    }

    private static func isASCIIOnly(_ text: String) -> Bool {
        !text.unicodeScalars.contains { $0.value > 127 }
    }
}