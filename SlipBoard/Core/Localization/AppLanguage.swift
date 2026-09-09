import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case vietnamese = "vi"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .english:
            "en_US"
        case .vietnamese:
            "vi_VN"
        }
    }

    var nativeDisplayName: String {
        switch self {
        case .english:
            "English"
        case .vietnamese:
            "Tiếng Việt"
        }
    }

    init(persistedRawValue: String?) {
        self = persistedRawValue.flatMap(Self.init(rawValue:)) ?? .english
    }
}
