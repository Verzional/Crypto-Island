import AppKit
import Carbon

/// Manages system-wide global hotkeys for the Dynamic Island using Carbon's RegisterEventHotKey.
/// This works system-wide across all applications without requiring macOS Accessibility permissions.
public final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let islandController: DynamicIslandController

    public init(islandController: DynamicIslandController) {
        self.islandController = islandController
        setupCarbonHotKey()
    }

    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func setupCarbonHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x434E5448), id: 1) // 'CNTH', 1
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    manager.handleHotKey()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        guard installStatus == noErr else {
            print("Failed to install Carbon event handler: \(installStatus)")
            return
        }

        // Register Option + Shift + C (kVK_ANSI_C = 8)
        let regStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            print("Failed to register Carbon hotkey: \(regStatus)")
        }
    }

    @MainActor
    private func handleHotKey() {
        islandController.toggleExpansion()
    }
}
