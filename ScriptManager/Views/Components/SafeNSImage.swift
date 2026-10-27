// ScriptManager/Views/Components/SafeNSImage.swift
import SwiftUI
import AppKit

/// 架构级增强：全局应用图标缓存池
class AppIconCache {
    static let shared = AppIconCache()
    private var cache = [URL: NSImage]()
    
    // 架构级修复：恢复并发队列，绝不阻塞主线程，解决唤醒启动器时的严重卡顿
    private let queue = DispatchQueue(label: "com.scriptmanager.iconQueue", attributes: .concurrent)
    
    func getIcon(for url: URL, completion: @escaping (NSImage) -> Void) {
        // 1. 内存缓存命中，直接返回
        if let cached = cache[url] {
            completion(cached)
            return
        }
        
        // 2. 异步提取与光栅化，彻底解放主线程
        queue.async {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            
            // 架构级防坑：在后台线程强制光栅化为纯位图，彻底剥离 NSIconCore 等动态渲染组件
            // 完美规避 SwiftUI 在渲染时触发 IconRendering.framework 的 Metal 崩溃
            let rasterized = icon.rasterized()
            
            DispatchQueue.main.async {
                self.cache[url] = rasterized
                completion(rasterized)
            }
        }
    }
}

extension NSImage {
    func rasterized() -> NSImage {
        // 架构级修复：使用 CGImage 强制将矢量/动态图标绘制为静态位图
        // 这是最底层、最安全的转换方式，比 tiffRepresentation 更稳定
        var rect = NSRect(origin: .zero, size: self.size)
        guard let cgImage = self.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return self
        }
        return NSImage(cgImage: cgImage, size: self.size)
    }
}

/// 架构级增强：支持异步加载与缓存的图标视图
public struct AppIconView: View {
    let url: URL
    @State private var image: NSImage?
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                // 占位符
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .onAppear {
            AppIconCache.shared.getIcon(for: url) { fetchedImage in
                self.image = fetchedImage
            }
        }
    }
}