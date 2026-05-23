//
//  SlipBoardApp.swift
//  SlipBoard
//
//  Created by huynq3 on 5/17/26.
//

import SwiftUI
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopup = KeyboardShortcuts.Name("togglePopup")
}

public class PopupPanelManager {
    public static let shared = PopupPanelManager()
    
    private var popupPanel: PopupPanel?
    private let historyEngine = MockHistoryEngine()
    private var clipboardMonitor: ClipboardMonitor?
    private var settingsStore: MockSettingsStore?
    
    private init() {}
    
    public func setup(settingsStore: MockSettingsStore) {
        self.settingsStore = settingsStore
        
        // Configure security manager and lock on launch if enabled
        SecurityManager.shared.configure(with: settingsStore)
        if settingsStore.lockSlipboard {
            SecurityManager.shared.lock()
        }
        
        KeyboardShortcuts.onKeyUp(for: .togglePopup) { [weak self] in
            self?.toggle()
        }
        
        // Instantiate and start background clipboard monitor
        let monitor = ClipboardMonitor(historyEngine: historyEngine, settingsStore: settingsStore)
        monitor.start()
        self.clipboardMonitor = monitor
    }
    
    public func toggle() {
        guard let settingsStore = settingsStore else { return }
        if popupPanel == nil {
            let gridView = PopupGridContainer(engine: historyEngine, settings: settingsStore)
            let hostingView = NSHostingView(rootView: gridView)
            let panel = PopupPanel(contentView: hostingView)
            popupPanel = panel
        }
        
        guard let panel = popupPanel else { return }
        
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            // Reset inactivity timer on show
            SecurityManager.shared.resetInactivityTimer()
            
            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
                ?? NSScreen.main
                ?? NSScreen.screens.first
            
            if let screen = screen {
                let screenFrame = screen.frame
                let panelSize = panel.frame.size
                let x = screenFrame.minX + (screenFrame.width - panelSize.width) / 2
                let y = screenFrame.minY + (screenFrame.height - panelSize.height) / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                panel.center()
            }
            
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct SlipBoardApp: App {
    @StateObject private var settingsStore: MockSettingsStore
    @StateObject private var statsProvider = MockHistoryStatsProvider()

    init() {
        let store = MockSettingsStore()
        self._settingsStore = StateObject(wrappedValue: store)
        PopupPanelManager.shared.setup(settingsStore: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        // 1. Menu Bar Item Scene
        MenuBarExtra {
            MenuBarDropdownView(settings: settingsStore, stats: statsProvider)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                if settingsStore.menuBarBadge {
                    Text("\(statsProvider.totalItemsCount)")
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)

        // 2. Settings Window Scene
        Window("Settings", id: "settings-window") {
            SettingsWindowView(settings: settingsStore)
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
