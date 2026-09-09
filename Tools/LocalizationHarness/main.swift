import Combine
import Foundation

@main
struct LocalizationHarness {
    static func main() async {
        await MainActor.run {
            let suiteName = "SlipBoard.LocalizationHarness.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }

            let storageKey = "harness.language"
            let store = LocalizationStore(defaults: defaults, storageKey: storageKey)
            expect(store.language == .english, "Fresh stores default to English")
            expect(store.text(.menuSettings) == "Settings...", "English catalog resolves typed keys")
            expect(LocalizationCatalog.defaultMissingKeys.isEmpty, "Default catalogs cover every typed key")

            var publishedLanguages: [AppLanguage] = []
            let observation = store.languagePublisher.sink { publishedLanguages.append($0) }
            store.setLanguage(.vietnamese)
            expect(store.language == .vietnamese, "Language changes live")
            expect(publishedLanguages.contains(.vietnamese), "Live changes are published")
            expect(store.text(.menuSettings) == "Cài đặt...", "Vietnamese catalog resolves typed keys")
            expect(store.text(.statusActive, ["value": "2s ago"]) == "Hoạt động 2s ago", "Named interpolation is catalog-backed")
            expect(store.text(.settingsOrganizationDescription).contains("cục bộ"), "Settings descriptions resolve in Vietnamese")
            expect(store.text(.menuPauseFor, ["duration": "15 min"]) == "Tạm dừng trong 15 min", "Menu templates interpolate named values")
            expect(store.text(.popupNoMatchingClips) == "Không có clip phù hợp", "Popup empty states resolve in Vietnamese")
            expect(store.text(.alertClearClipboardHistoryMessage).contains("vĩnh viễn"), "Alert copy resolves in Vietnamese")
            expect(store.text(.statusExcludedIn, ["app": "Safari"]) == "Đã loại trừ trong Safari", "Dynamic status templates preserve user app names")
            expect(store.text(.popupSortNewestFirst) == "Mới nhất trước", "Popup sort labels resolve in Vietnamese")
            expect(store.text(.overlayMarkdownDescription).contains("Markdown"), "Transform descriptions resolve in Vietnamese")
            expect(store.text(.securityLockDetailManual).contains("mở khóa"), "Security lock details resolve in Vietnamese")
            expect(store.text(.bridgeOneShotTTL, ["minutes": "10"]) == "TTL 10 phút", "Bridge TTL templates interpolate named values")
            expect(store.text(.hotkeyRecorderInstruction).contains("phím tắt"), "Hotkey recorder instructions resolve in Vietnamese")
            expect(store.text(.bridgeScopeLabel) == "Phạm vi", "Bridge scope label resolves in Vietnamese")
            expect(store.text(.bridgeSupportedPastesV1Detail).contains("Bridge trong v1"), "Bridge scope detail resolves in Vietnamese")
            expect(store.text(.bridgeNoDevicesDetail).contains("iPhone"), "Bridge no-devices detail resolves in Vietnamese")
            expect(store.text(.bridgeSubtitleFallback).contains("Lịch sử Mac cục bộ"), "Bridge subtitle fallback resolves in Vietnamese")
            expect(store.plural(.historyItemCount, count: 1) == "1 mục", "Vietnamese singular count resolves")
            expect(store.plural(.historyItemCount, count: 2) == "2 mục", "Vietnamese plural count resolves")
            expect(store.format(byteCount: 1_024).contains("KB"), "Byte formatting produces a localized unit")

            let restoredStore = LocalizationStore(defaults: defaults, storageKey: storageKey)
            expect(restoredStore.language == .vietnamese, "Selection persists through a new store")

            defaults.set("unsupported-language", forKey: storageKey)
            let fallbackStore = LocalizationStore(defaults: defaults, storageKey: storageKey)
            expect(fallbackStore.language == .english, "Invalid persisted values fall back to English")

            let incompleteCatalog = LocalizationCatalog(
                english: [.menuSettings: "Settings..."],
                vietnamese: [:]
            )
            let incompleteStore = LocalizationStore(
                defaults: defaults,
                storageKey: "harness.incomplete",
                catalog: incompleteCatalog
            )
            incompleteStore.setLanguage(.vietnamese)
            expect(incompleteStore.text(.menuSettings) == "Settings...", "Missing translations fall back to English")
            expect(incompleteStore.text(.menuQuit) == "Quit SlipBoard", "Missing catalog entries use deterministic English fallback")
            expect(incompleteStore.lastFallback?.key == .menuQuit, "Missing catalog fallback is observable")

            withExtendedLifetime(observation) {}
            print("LocalizationHarness: PASS")
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError("LocalizationHarness assertion failed: \(message)")
        }
    }
}
