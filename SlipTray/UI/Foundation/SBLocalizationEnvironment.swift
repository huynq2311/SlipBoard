import SwiftUI

private struct SBLocalizationProviderKey: EnvironmentKey {
    static let defaultValue: AppLocalizationProviding? = nil
}

private struct SBLocalizationLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var sbLocalization: AppLocalizationProviding? {
        get { self[SBLocalizationProviderKey.self] }
        set { self[SBLocalizationProviderKey.self] = newValue }
    }

    /// This value is supplied alongside `sbLocalization` by the app shell.
    /// Reading it gives SwiftUI a value dependency so open shells redraw after
    /// the store publishes a language change.
    var sbLocalizationLanguage: AppLanguage {
        get { self[SBLocalizationLanguageKey.self] }
        set { self[SBLocalizationLanguageKey.self] = newValue }
    }
}

extension View {
    func sbLocalization(_ provider: AppLocalizationProviding, language: AppLanguage) -> some View {
        environment(\.sbLocalization, provider)
            .environment(\.sbLocalizationLanguage, language)
    }
}

/// View-local resolver for shared shell copy. The optional provider makes
/// previews safe: all keys retain their catalog's English fallback until the
/// app injects its observable `LocalizationStore`.
@propertyWrapper
struct SBLocalizedCopy: DynamicProperty {
    @Environment(\.sbLocalization) private var provider
    @Environment(\.sbLocalizationLanguage) private var language

    var wrappedValue: SBLocalizedCopy { self }

    var currentLanguage: AppLanguage { language }

    func text(_ key: LocalizationKey, _ arguments: [String: String] = [:]) -> String {
        _ = language
        return provider?.text(key, arguments) ?? key.englishFallback
    }
}
