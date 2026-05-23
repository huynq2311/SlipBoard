import Foundation
import AppKit
import Combine

public class ClipboardMonitor {
    private let historyEngine: MockHistoryEngine
    private let settingsStore: MockSettingsStore
    
    private let queue = DispatchQueue(label: "com.slipboard.clipboard", qos: .background)
    private var timer: DispatchSourceTimer?
    
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var activeAppHistory: [(Date, String, String)] = []
    
    public init(historyEngine: MockHistoryEngine, settingsStore: MockSettingsStore) {
        self.historyEngine = historyEngine
        self.settingsStore = settingsStore
        setupFocusTracking()
    }
    
    public func start() {
        queue.async { [weak self] in
            self?.startTimer()
        }
    }
    
    public func stop() {
        queue.async { [weak self] in
            self?.stopTimer()
        }
    }
    
    private func startTimer() {
        stopTimer()
        
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 0.5)
        t.setEventHandler { [weak self] in
            self?.checkPasteboard()
        }
        t.resume()
        self.timer = t
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func setupFocusTracking() {
        // Listen to focus changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Initial focus seed
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            let name = frontmost.localizedName ?? "Unknown"
            let bundleId = frontmost.bundleIdentifier ?? "unknown"
            recordActiveApp(bundleId: bundleId, name: name, date: Date())
        }
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let name = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? "unknown"
        let date = Date()
        
        queue.async { [weak self] in
            self?.recordActiveApp(bundleId: bundleId, name: name, date: date)
        }
    }
    
    private func recordActiveApp(bundleId: String, name: String, date: Date) {
        activeAppHistory.append((date, bundleId, name))
        if activeAppHistory.count > 10 {
            activeAppHistory.removeFirst()
        }
    }
    
    private func checkPasteboard() {
        // Obey pause settings check
        guard !settingsStore.pauseCapture else { return }
        if let pauseUntil = settingsStore.pauseUntil, pauseUntil > Date() { return }
        
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        let now = Date()
        var resolvedApp = ("unknown", "Unknown")
        
        // Heuristic correlation of active focus timeline
        if let matched = activeAppHistory.last(where: { $0.0 <= now }) {
            resolvedApp = (matched.1, matched.2)
        } else if let frontmost = NSWorkspace.shared.frontmostApplication {
            resolvedApp = (frontmost.bundleIdentifier ?? "unknown", frontmost.localizedName ?? "Unknown")
        }
        
        // Exclusions check
        let resolvedBundleId = resolvedApp.0
        let resolvedName = resolvedApp.1
        let isExcluded = settingsStore.excludedApps.contains { app in
            let matchBundle = app.bundleIdentifier.localizedCaseInsensitiveCompare(resolvedBundleId) == .orderedSame
            let matchName = app.name.localizedCaseInsensitiveCompare(resolvedName) == .orderedSame
            return matchBundle || matchName
        }
        guard !isExcluded else { return }
        
        handleCapturedContent(bundleId: resolvedApp.0, appName: resolvedApp.1)
    }
    
    private func handleCapturedContent(bundleId: String, appName: String) {
        let pboard = NSPasteboard.general
        
        // Classification logic
        var type: ClipType = .text
        var content = ""
        
        // 1. Files Check
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let fileTypes = pboard.propertyList(forType: filenamesType) as? [String], !fileTypes.isEmpty {
            type = .file
            content = fileTypes.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        }
        // 2. Image Check
        else if pboard.types?.contains(.tiff) == true || pboard.types?.contains(.png) == true {
            type = .image
            content = "image_asset_\(Int(Date().timeIntervalSince1970)).png"
        }
        // 3. String Check (URLs, Code, or Text)
        else if let str = pboard.string(forType: .string), !str.isEmpty {
            content = str
            
            if str.lowercased().hasPrefix("http://") || str.lowercased().hasPrefix("https://") {
                type = .url
            } else if isCodeBlock(str, bundleId: bundleId) {
                type = .code
            } else {
                type = .text
            }
        } else {
            // Nothing readable
            return
        }
        
        // Create new ClipItem and append it safely on the main queue
        let icon = mapAppIcon(bundleId: bundleId)
        let item = ClipItem(
            contentType: type,
            contentString: content,
            sourceApp: appName,
            sourceAppIcon: icon,
            timestamp: Date(),
            isPinned: false
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.historyEngine.items.append(item)
        }
    }
    
    private func isCodeBlock(_ text: String, bundleId: String) -> Bool {
        // Source editor heuristic
        let editorIDs = ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.googlecode.iterm2", "com.apple.Terminal"]
        if editorIDs.contains(where: { bundleId.localizedCaseInsensitiveContains($0) }) {
            return true
        }
        
        // Syntax heuristic
        let codeKeywords = ["func ", "var ", "let ", "import ", "struct ", "class ", "interface ", "public ", "private ", "void ", "return ", "const ", "async ", "await ", "throws "]
        let lineCount = text.components(separatedBy: .newlines).count
        
        if lineCount >= 2 {
            // Check braces or keywords
            if text.contains("{") && text.contains("}") {
                return true
            }
            for kw in codeKeywords {
                if text.contains(kw) {
                    return true
                }
            }
        }
        return false
    }
    
    private func mapAppIcon(bundleId: String) -> String {
        let id = bundleId.lowercased()
        if id.contains("safari") || id.contains("chrome") || id.contains("firefox") || id.contains("arc") || id.contains("edge") {
            return "network"
        } else if id.contains("terminal") || id.contains("warp") || id.contains("iterm") {
            return "terminal"
        } else if id.contains("xcode") || id.contains("vscode") || id.contains("cursor") {
            return "curlybraces"
        } else if id.contains("figma") || id.contains("sketch") || id.contains("photoshop") {
            return "paintpalette"
        } else if id.contains("finder") {
            return "folder"
        } else if id.contains("slack") || id.contains("discord") || id.contains("messages") {
            return "bubble.left.and.bubble.right"
        }
        return "app.badge"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopTimer()
    }
}
