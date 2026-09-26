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

    @Published public var favorites: [String] {
        didSet { UserDefaults.standard.set(favorites, forKey: "CryptoIsland_Favorites") }
    }

    @Published public var gridSlots: [StatMetric] {
        didSet {
            let raw = gridSlots.map { $0.rawValue }
            UserDefaults.standard.set(raw, forKey: "CryptoIsland_GridSlots")
        }
    }

    public init() {
        self.isPinned = UserDefaults.standard.bool(forKey: "CryptoIsland_IsPinned")
        self.stealthMode = UserDefaults.standard.bool(forKey: "CryptoIsland_StealthMode")
        let savedDelay = UserDefaults.standard.double(forKey: "CryptoIsland_AutoCollapseDelay")
        self.autoCollapseDelay = savedDelay > 0 ? savedDelay : 1.2
        self.globalHotKeyEnabled = UserDefaults.standard.object(forKey: "CryptoIsland_HotKeyEnabled") as? Bool ?? true

        let saved = UserDefaults.standard.stringArray(forKey: "CryptoIsland_Favorites") ?? []
        let oldDefaults = ["BTCUSDT", "ETHUSDT", "SOLUSDT", "ARBUSDT", "DOGEUSDT", "PEPEUSDT"]
        if saved == oldDefaults {
            self.favorites = []
            UserDefaults.standard.set([], forKey: "CryptoIsland_Favorites")
        } else {
            self.favorites = saved
        }

        let oldDefaultsV1 = ["24h_high", "24h_low", "vwap", "15m_vol", "5m_vol", "5m_buy_ratio"]
        let savedSlots = UserDefaults.standard.stringArray(forKey: "CryptoIsland_GridSlots") ?? []
        let parsedSlots = savedSlots.compactMap { StatMetric(rawValue: $0) }
        if parsedSlots.count == 6 && savedSlots != oldDefaultsV1 {
            self.gridSlots = parsedSlots
        } else {
            self.gridSlots = StatMetric.defaultSlots
            let raw = StatMetric.defaultSlots.map { $0.rawValue }
            UserDefaults.standard.set(raw, forKey: "CryptoIsland_GridSlots")
        }
    }

    public func updateGridSlot(at index: Int, to metric: StatMetric) {
        guard index >= 0 && index < gridSlots.count else { return }
        gridSlots[index] = metric
    }

    public func resetGridSlots() {
        gridSlots = StatMetric.defaultSlots
    }

    public func isFavorite(_ symbol: String) -> Bool {
        let clean = CryptoSymbol.from(rawInput: symbol).symbol
        return favorites.contains(clean)
    }

    @discardableResult
    public func toggleFavorite(_ symbol: String) -> Bool {
        let clean = CryptoSymbol.from(rawInput: symbol).symbol
        if let index = favorites.firstIndex(of: clean) {
            favorites.remove(at: index)
            return true
        } else {
            if favorites.count >= 9 {
                return false
            }
            favorites.append(clean)
            return true
        }
    }
}
