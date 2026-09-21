import Foundation
import Combine

/// User preferences for Dynamic Island behavior and appearance.
@MainActor
public final class SettingsModel: ObservableObject {
    @Published public var isPinned: Bool {
        didSet { UserDefaults.standard.set(isPinned, forKey: "CryptoIsland_IsPinned") }
    }

    @Published public var stealthMode: Bool {
        didSet { UserDefaults.standard.set(stealthMode, forKey: "CryptoIsland_StealthMode") }
    }

    @Published public var autoCollapseDelay: Double {
        didSet { UserDefaults.standard.set(autoCollapseDelay, forKey: "CryptoIsland_AutoCollapseDelay") }
    }

    @Published public var globalHotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(globalHotKeyEnabled, forKey: "CryptoIsland_HotKeyEnabled") }
    }

    public init() {
        self.isPinned = UserDefaults.standard.bool(forKey: "CryptoIsland_IsPinned")
        self.stealthMode = UserDefaults.standard.bool(forKey: "CryptoIsland_StealthMode")
        let savedDelay = UserDefaults.standard.double(forKey: "CryptoIsland_AutoCollapseDelay")
        self.autoCollapseDelay = savedDelay > 0 ? savedDelay : 1.2
        self.globalHotKeyEnabled = UserDefaults.standard.object(forKey: "CryptoIsland_HotKeyEnabled") as? Bool ?? true
    }
}
