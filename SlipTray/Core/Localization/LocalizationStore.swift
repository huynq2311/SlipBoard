import Combine
import Foundation

@MainActor
protocol AppLocalizationProviding: AnyObject {
    var language: AppLanguage { get }
    func text(_ key: LocalizationKey, _ arguments: [String: String]) -> String
    func setLanguage(_ language: AppLanguage)
}

struct LocalizationFallbackEvent: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case missingTranslation
        case missingEnglishTemplate
    }

    let key: LocalizationKey
    let requestedLanguage: AppLanguage
    let reason: Reason
}

@MainActor
final class LocalizationStore: ObservableObject, AppLocalizationProviding {
    nonisolated static let defaultStorageKey = "SlipTray.Localization.language"

    @Published private(set) var language: AppLanguage
    @Published private(set) var lastFallback: LocalizationFallbackEvent?

    var languagePublisher: AnyPublisher<AppLanguage, Never> {
        $language.eraseToAnyPublisher()
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let catalog: LocalizationCatalog

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = LocalizationStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        catalog = LocalizationCatalog()
        language = AppLanguage(persistedRawValue: defaults.string(forKey: storageKey))
        lastFallback = nil
    }

    init(
        defaults: UserDefaults,
        storageKey: String = LocalizationStore.defaultStorageKey,
        catalog: LocalizationCatalog
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.catalog = catalog
        language = AppLanguage(persistedRawValue: defaults.string(forKey: storageKey))
        lastFallback = nil
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
        defaults.set(language.rawValue, forKey: storageKey)
    }

    func text(_ key: LocalizationKey, _ arguments: [String: String] = [:]) -> String {
        let template: String

        if let localizedTemplate = catalog.template(for: key, language: language) {
            template = localizedTemplate
        } else if let englishTemplate = catalog.englishTemplate(for: key) {
            lastFallback = LocalizationFallbackEvent(
                key: key,
                requestedLanguage: language,
                reason: .missingTranslation
            )
            template = englishTemplate
        } else {
            lastFallback = LocalizationFallbackEvent(
                key: key,
                requestedLanguage: language,
                reason: .missingEnglishTemplate
            )
            template = key.englishFallback
        }

        return interpolate(template, arguments: arguments)
    }

    func plural(_ key: LocalizationKey, count: Int) -> String {
        let formattedCount = format(number: count)

        switch key {
        case .historyItemCount:
            switch language {
            case .english:
                return "\(formattedCount) \(count == 1 ? "item" : "items")"
            case .vietnamese:
                return "\(formattedCount) mục"
            }
        default:
            return text(key, ["count": formattedCount])
        }
    }

    func format(number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    func format(byteCount: Int64) -> String {
        let absoluteByteCount = abs(Double(byteCount))
        let units = ["B", "KB", "MB", "GB", "TB"]
        var unitIndex = 0
        var value = absoluteByteCount

        while value >= 1_024, unitIndex < units.count - 1 {
            value /= 1_024
            unitIndex += 1
        }

        if byteCount < 0 {
            value *= -1
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = unitIndex == 0 ? 0 : 1
        let number = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return "\(number) \(units[unitIndex])"
    }

    func format(date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func interpolate(_ template: String, arguments: [String: String]) -> String {
        arguments.reduce(template) { result, argument in
            result.replacingOccurrences(of: "%{\(argument.key)}", with: argument.value)
        }
    }
}
