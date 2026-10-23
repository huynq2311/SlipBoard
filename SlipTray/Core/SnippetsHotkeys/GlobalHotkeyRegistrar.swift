import AppKit
import Carbon
import Foundation

@MainActor
final class HotkeyRecorderKeyEventMonitor {
    var onDescriptorCaptured: ((HotkeyDescriptor) -> Void)?
    var onCancel: (() -> Void)?

    var isActive: Bool {
        monitorToken != nil
    }

    private var monitorToken: Any?

    init(
        onDescriptorCaptured: ((HotkeyDescriptor) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.onDescriptorCaptured = onDescriptorCaptured
        self.onCancel = onCancel
    }

    deinit {
        if let monitorToken {
            NSEvent.removeMonitor(monitorToken)
        }
    }

    func start() {
        guard monitorToken == nil else {
            return
        }

        monitorToken = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else {
                return event
            }

            return self.handleCapturedEvent(event)
        }
    }

    func stop() {
        guard let monitorToken else {
            return
        }

        NSEvent.removeMonitor(monitorToken)
        self.monitorToken = nil
    }

    private func handleCapturedEvent(_ event: NSEvent) -> NSEvent? {
        if Int(event.keyCode) == kVK_Escape {
            stop()
            onCancel?()
            return nil
        }

        guard event.isARepeat == false else {
            return nil
        }

        let modifiers = event.hotkeyModifiers
        guard modifiers.isEmpty == false else {
            return nil
        }

        guard let capturedKey = CapturedRecorderKey(event: event) else {
            return nil
        }

        let descriptor = HotkeyDescriptor(
            keyCode: Int(event.keyCode),
            keyEquivalent: capturedKey.keyEquivalent,
            modifiers: modifiers,
            displayLabel: modifiers.map(\.displaySymbol).joined() + capturedKey.displayKey
        )

        stop()
        onDescriptorCaptured?(descriptor)
        return nil
    }
}

final class GlobalHotkeyRegistrar: HotkeyRegistering {
    var onBindingTriggered: ((HotkeyBindingTarget, HotkeyDescriptor) -> Void)?

    var registeredBindings: [HotkeyRegistrationRecord] {
        registrationsByTargetID.values.sorted { lhs, rhs in
            lhs.registeredAt < rhs.registeredAt
        }
    }

    private var registrationsByTargetID: [String: HotkeyRegistrationRecord] = [:]
    private var hotKeyRefsByTargetID: [String: EventHotKeyRef] = [:]
    private var hotKeyTargetsByID: [UInt32: HotkeyBindingTarget] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var handlerRef: EventHandlerRef?

    init() {
        installHandlerIfNeeded()
    }

    deinit {
        _ = clearRegisteredBindings()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    @discardableResult
    func registerBinding(_ request: HotkeyRegistrationRequest) -> HotkeyRegistrationRecord? {
        guard request.availability == .enabled else {
            _ = unregisterBinding(for: request.target)
            return nil
        }

        installHandlerIfNeeded()
        _ = unregisterBinding(for: request.target)

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: allocateHotKeyID())
        let status = RegisterEventHotKey(
            UInt32(request.descriptor.keyCode),
            request.descriptor.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            return nil
        }

        let record = HotkeyRegistrationRecord(
            target: request.target,
            descriptor: request.descriptor,
            registeredAt: .now,
            availability: request.availability
        )

        let targetID = request.target.id
        registrationsByTargetID[targetID] = record
        hotKeyRefsByTargetID[targetID] = hotKeyRef
        hotKeyTargetsByID[hotKeyID.id] = request.target
        return record
    }

    @discardableResult
    func registerBindings(_ requests: [HotkeyRegistrationRequest]) -> [HotkeyRegistrationRecord] {
        requests.compactMap(registerBinding)
    }

    @discardableResult
    func unregisterBinding(for target: HotkeyBindingTarget) -> HotkeyRegistrationRecord? {
        let targetID = target.id
        let removedRecord = registrationsByTargetID.removeValue(forKey: targetID)

        if let hotKeyRef = hotKeyRefsByTargetID.removeValue(forKey: targetID) {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let removedRecord {
            hotKeyTargetsByID = hotKeyTargetsByID.filter { $0.value != removedRecord.target }
        }

        return removedRecord
    }

    @discardableResult
    func clearRegisteredBindings() -> Int {
        let count = registrationsByTargetID.count

        for (_, hotKeyRef) in hotKeyRefsByTargetID {
            UnregisterEventHotKey(hotKeyRef)
        }

        registrationsByTargetID.removeAll()
        hotKeyRefsByTargetID.removeAll()
        hotKeyTargetsByID.removeAll()
        return count
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard
                    let eventRef,
                    let userData
                else {
                    return OSStatus(eventNotHandledErr)
                }

                let registrar = Unmanaged<GlobalHotkeyRegistrar>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return registrar.handleHotKeyEvent(eventRef)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    private func handleHotKeyEvent(_ eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard
            let target = hotKeyTargetsByID[hotKeyID.id],
            let record = registrationsByTargetID[target.id]
        else {
            return noErr
        }

        onBindingTriggered?(target, record.descriptor)
        return noErr
    }

    private func allocateHotKeyID() -> UInt32 {
        defer { nextHotKeyID += 1 }
        return nextHotKeyID
    }

    private static let signature = fourCharCode("SLPB")
}

private extension HotkeyDescriptor {
    var carbonModifierFlags: UInt32 {
        modifiers.reduce(0) { partialResult, modifier in
            partialResult | modifier.carbonModifierFlag
        }
    }
}

private extension HotkeyModifier {
    var carbonModifierFlag: UInt32 {
        switch self {
        case .command:
            return UInt32(cmdKey)
        case .shift:
            return UInt32(shiftKey)
        case .option:
            return UInt32(optionKey)
        case .control:
            return UInt32(controlKey)
        case .function:
            return UInt32(kEventKeyModifierFnMask)
        }
    }
}

private extension NSEvent {
    var hotkeyModifiers: [HotkeyModifier] {
        let relevantFlags: [(NSEvent.ModifierFlags, HotkeyModifier)] = [
            (.control, .control),
            (.option, .option),
            (.shift, .shift),
            (.command, .command),
            (.function, .function)
        ]

        return relevantFlags.compactMap { modifierFlags.contains($0.0) ? $0.1 : nil }
    }
}

private struct CapturedRecorderKey {
    let keyEquivalent: String
    let displayKey: String

    init(keyEquivalent: String, displayKey: String) {
        self.keyEquivalent = keyEquivalent
        self.displayKey = displayKey
    }

    init?(event: NSEvent) {
        if let specialKey = Self.specialKey(for: Int(event.keyCode)) {
            self = specialKey
            return
        }

        guard let characters = event.charactersIgnoringModifiers else {
            return nil
        }

        let trimmedCharacters = characters.trimmingCharacters(in: .controlCharacters)
        guard trimmedCharacters.isEmpty == false else {
            return nil
        }

        if trimmedCharacters == " " {
            self = Self(keyEquivalent: "space", displayKey: "Space")
            return
        }

        let keyEquivalent = String(trimmedCharacters.prefix(1)).lowercased()
        guard keyEquivalent.isEmpty == false else {
            return nil
        }

        self.init(
            keyEquivalent: keyEquivalent,
            displayKey: keyEquivalent.uppercased()
        )
    }

    private static func specialKey(for keyCode: Int) -> Self? {
        switch keyCode {
        case kVK_Return:
            return Self(keyEquivalent: "return", displayKey: "Return")
        case kVK_Tab:
            return Self(keyEquivalent: "tab", displayKey: "Tab")
        case kVK_Space:
            return Self(keyEquivalent: "space", displayKey: "Space")
        case kVK_Delete:
            return Self(keyEquivalent: "delete", displayKey: "Delete")
        case kVK_ForwardDelete:
            return Self(keyEquivalent: "forwardDelete", displayKey: "Del")
        case kVK_Home:
            return Self(keyEquivalent: "home", displayKey: "Home")
        case kVK_End:
            return Self(keyEquivalent: "end", displayKey: "End")
        case kVK_PageUp:
            return Self(keyEquivalent: "pageUp", displayKey: "PgUp")
        case kVK_PageDown:
            return Self(keyEquivalent: "pageDown", displayKey: "PgDn")
        case kVK_LeftArrow:
            return Self(keyEquivalent: "leftArrow", displayKey: "\u{2190}")
        case kVK_RightArrow:
            return Self(keyEquivalent: "rightArrow", displayKey: "\u{2192}")
        case kVK_UpArrow:
            return Self(keyEquivalent: "upArrow", displayKey: "\u{2191}")
        case kVK_DownArrow:
            return Self(keyEquivalent: "downArrow", displayKey: "\u{2193}")
        default:
            return functionKey(for: keyCode)
        }
    }

    private static func functionKey(for keyCode: Int) -> Self? {
        let mapping: [Int: String] = [
            kVK_F1: "F1",
            kVK_F2: "F2",
            kVK_F3: "F3",
            kVK_F4: "F4",
            kVK_F5: "F5",
            kVK_F6: "F6",
            kVK_F7: "F7",
            kVK_F8: "F8",
            kVK_F9: "F9",
            kVK_F10: "F10",
            kVK_F11: "F11",
            kVK_F12: "F12",
            kVK_F13: "F13",
            kVK_F14: "F14",
            kVK_F15: "F15",
            kVK_F16: "F16",
            kVK_F17: "F17",
            kVK_F18: "F18",
            kVK_F19: "F19",
            kVK_F20: "F20"
        ]

        guard let label = mapping[keyCode] else {
            return nil
        }

        return Self(
            keyEquivalent: label.lowercased(),
            displayKey: label
        )
    }
}

private func fourCharCode(_ text: String) -> OSType {
    text.utf8.reduce(0) { partialResult, scalar in
        (partialResult << 8) + OSType(scalar)
    }
}
