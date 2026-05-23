import Foundation

public enum ThemeOption: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var id: String { self.rawValue }
}

public enum RetentionOption: String, CaseIterable, Identifiable, Codable {
    case oneWeek = "7d"
    case twoWeeks = "14d"
    case oneMonth = "30d"
    case threeMonths = "90d"
    case never = "∞"
    
    public var id: String { self.rawValue }
    
    public var label: String {
        switch self {
        case .oneWeek: return "7 days"
        case .twoWeeks: return "14 days"
        case .oneMonth: return "30 days"
        case .threeMonths: return "90 days"
        case .never: return "Forever"
        }
    }
}

public protocol SettingsStoreProtocol: ObservableObject {
    var launchAtLogin: Bool { get set }
    var showDockIcon: Bool { get set }
    var theme: ThemeOption { get set }
    var menuBarBadge: Bool { get set }
    var enableBridge: Bool { get set }
    var maxHistoryItems: Int { get set }
    var retentionPeriod: RetentionOption { get set }
    var excludedApps: [ExcludedApp] { get set }
    
    func addExcludedApp(_ app: ExcludedApp)
    func removeExcludedApp(_ app: ExcludedApp)
}
