import Foundation
import Combine

/// A reactive mock store implementation of `SettingsStoreProtocol` for the App Shell.
public class MockSettingsStore: SettingsStoreProtocol {
    @Published public var launchAtLogin: Bool = false
    @Published public var showDockIcon: Bool = true
    @Published public var theme: ThemeOption = .system
    @Published public var menuBarBadge: Bool = true
    @Published public var enableBridge: Bool = false
    @Published public var maxHistoryItems: Int = 500
    @Published public var retentionPeriod: RetentionOption = .threeMonths
    @Published public var excludedApps: [ExcludedApp] = []
    
    public init() {
        // Pre-populate with typical exclusion list items from design prototypes
        self.excludedApps = [
            ExcludedApp(name: "1Password", bundleIdentifier: "com.agilebits.onepassword7", category: "Security"),
            ExcludedApp(name: "Keychain Access", bundleIdentifier: "com.apple.keychainaccess", category: "System Settings"),
            ExcludedApp(name: "Finance Pro", bundleIdentifier: "com.custom.financepro", category: "Finance")
        ]
    }
    
    public func addExcludedApp(_ app: ExcludedApp) {
        if !excludedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            excludedApps.append(app)
        }
    }
    
    public func removeExcludedApp(_ app: ExcludedApp) {
        excludedApps.removeAll(where: { $0.id == app.id })
    }
}

/// A reactive mock store implementation of `HistoryStatsProvider` for the App Shell.
public class MockHistoryStatsProvider: HistoryStatsProvider {
    @Published public var totalItemsCount: Int = 847
    @Published public var currentRetentionLabel: String = "90 days"
    
    public init() {}
}
