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
    
    private init() {}
    
    public func setup() {
        KeyboardShortcuts.onKeyUp(for: .togglePopup) { [weak self] in
            self?.toggle()
        }
    }
    
    public func toggle() {
        if popupPanel == nil {
            let hostingView = NSHostingView(rootView: PopupPanelPlaceholderView())
            let panel = PopupPanel(contentView: hostingView)
            popupPanel = panel
        }
        
        guard let panel = popupPanel else { return }
        
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct SlipBoardApp: App {
    @StateObject private var settingsStore = MockSettingsStore()
    @StateObject private var statsProvider = MockHistoryStatsProvider()

    init() {
        PopupPanelManager.shared.setup()
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
