import AppKit

/// Manages hotkey triggers and top-edge mouse tracking for the Dynamic Island.
@MainActor
public final class HotKeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let islandController: DynamicIslandController

    public init(islandController: DynamicIslandController) {
        self.islandController = islandController
        setupMonitors()
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupMonitors() {
        // Monitor key down for Control + Option + C to toggle island
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }

        // Global monitor (works when permitted by macOS accessibility or when active)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check for Control (0x40000) + Option (0x80000) + 'C' (keyCode 8)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains([.control, .option]) && event.keyCode == 8 {
            islandController.toggleExpansion()
            return true
        }
        return false
    }
}
