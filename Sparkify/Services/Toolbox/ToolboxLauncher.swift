//
//  ToolboxLauncher.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import AppKit
import Foundation

@MainActor
final class ToolboxLauncher {
    static let shared = ToolboxLauncher()

    private let iconCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let iconQueue = DispatchQueue(label: "com.sparkify.toolbox.icon", qos: .userInitiated)

    private init() {
        let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = cachesRoot
            .appendingPathComponent("com.sparkify.toolbox", isDirectory: true)
            .appendingPathComponent("icons", isDirectory: true)
        cacheDirectory = directory

        if fileManager.fileExists(atPath: directory.path) == false {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }

        iconCache.countLimit = 16
    }

    // MARK: - Public API

    @discardableResult
    func open(_ app: ToolboxApp) -> Bool {
        switch app.launchTarget {
        case let .native(bundleID, fallbackURL):
            let opened = NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleID, options: [.async], additionalEventParamDescriptor: nil, launchIdentifier: nil)
            if opened {
                return true
            }
            if let fallbackURL {
                return NSWorkspace.shared.open(fallbackURL)
            }
            return false

        case let .web(url):
            return NSWorkspace.shared.open(url)
        }
    }

    func icon(for app: ToolboxApp, targetSize: CGSize = CGSize(width: 48, height: 48)) async -> NSImage? {
        if let cached = iconCache.object(forKey: app.id as NSString) {
            return cached
        }

        if let diskImage = loadIconFromDisk(for: app.id) {
            let sized = resizedIcon(diskImage, to: targetSize)
            iconCache.setObject(sized, forKey: app.id as NSString)
            return sized
        }

        for source in app.iconSources {
            if let result = await fetchIcon(from: source, appID: app.id, targetSize: targetSize) {
                iconCache.setObject(result, forKey: app.id as NSString)
                return result
            }
        }

        return nil
    }

    func evictCache(for appID: String? = nil) {
        // Clear memory cache
        if let appID {
            iconCache.removeObject(forKey: appID as NSString)
            // Clear disk cache for specific app
            let url = cacheDirectory.appendingPathComponent("\(appID).png")
            try? fileManager.removeItem(at: url)
        } else {
            iconCache.removeAllObjects()
            // Clear all disk cache files
            if let cachedFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
                for fileURL in cachedFiles {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }

    // MARK: - Icon Loading

    private func fetchIcon(from source: ToolboxApp.IconSource, appID: String, targetSize: CGSize) async -> NSImage? {
        switch source {
        case let .appBundle(bundleID):
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return nil
            }
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = targetSize
            persist(icon: icon, appID: appID)
            return icon

        case let .remoteFavicon(url):
            return await loadRemoteIcon(from: url, appID: appID, targetSize: targetSize)

        case let .systemImage(name):
            guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
                return nil
            }
            symbol.size = targetSize
            return symbol
        }
    }

    private func loadRemoteIcon(from url: URL, appID: String, targetSize: CGSize) async -> NSImage? {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<400).contains(httpResponse.statusCode) else {
                return nil
            }
            guard let image = NSImage(data: data) else {
                return nil
            }
            let resized = resizedIcon(image, to: targetSize)
            persist(icon: resized, appID: appID)
            return resized
        } catch {
            print("⚠️ [Toolbox] Failed to fetch favicon for \(appID): \(error)")
            return nil
        }
    }

    private func loadIconFromDisk(for appID: String) -> NSImage? {
        let url = cacheDirectory.appendingPathComponent("\(appID).png")
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        return image
    }

    private func persist(icon: NSImage, appID: String) {
        let url = cacheDirectory.appendingPathComponent("\(appID).png")
        iconQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard let data = strongSelf.pngData(from: icon) else {
                return
            }
            do {
                try data.write(to: url, options: [.atomic])
            } catch {
                print("⚠️ [Toolbox] Failed to persist icon for \(appID): \(error)")
            }
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }
        return data
    }

    private func resizedIcon(_ image: NSImage, to size: CGSize) -> NSImage {
        if image.size == size {
            return image
        }

        let result = NSImage(size: size)
        result.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        result.unlockFocus()
        result.isTemplate = image.isTemplate
        return result
    }
}
