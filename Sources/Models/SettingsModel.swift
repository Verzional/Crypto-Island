import Foundation
import Combine

/// User preferences for Dynamic Island / Notch behavior and appearance.
@MainActor
public final class SettingsModel: ObservableObject {
    @Published public var isPinned: Bool {
        didSet { UserDefaults.standard.set(isPinned, forKey: "CryptoNotch_IsPinned") }
    }

    @Published public var stealthMode: Bool {
        didSet { UserDefaults.standard.set(stealthMode, forKey: "CryptoNotch_StealthMode") }
    }

    @Published public var autoCollapseDelay: Double {
        didSet { UserDefaults.standard.set(autoCollapseDelay, forKey: "CryptoNotch_AutoCollapseDelay") }
    }

    @Published public var globalHotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(globalHotKeyEnabled, forKey: "CryptoNotch_HotKeyEnabled") }
    }

    @Published public var favorites: [String] {
        didSet { UserDefaults.standard.set(favorites, forKey: "CryptoNotch_Favorites") }
    }

    @Published public var gridSlots: [StatMetric] {
        didSet {
            let raw = gridSlots.map { $0.rawValue }
            UserDefaults.standard.set(raw, forKey: "CryptoNotch_GridSlots")
        }
    }

    public init() {
        // Migration helpers checking CryptoNotch first, fallback to legacy CryptoAtoll / CryptoIsland
        let pinned = UserDefaults.standard.object(forKey: "CryptoNotch_IsPinned") as? Bool
            ?? UserDefaults.standard.object(forKey: "CryptoAtoll_IsPinned") as? Bool
            ?? UserDefaults.standard.bool(forKey: "CryptoIsland_IsPinned")
        self.isPinned = pinned

        let stealth = UserDefaults.standard.object(forKey: "CryptoNotch_StealthMode") as? Bool
            ?? UserDefaults.standard.object(forKey: "CryptoAtoll_StealthMode") as? Bool
            ?? UserDefaults.standard.bool(forKey: "CryptoIsland_StealthMode")
        self.stealthMode = stealth

        var savedDelay = UserDefaults.standard.double(forKey: "CryptoNotch_AutoCollapseDelay")
        if savedDelay <= 0 {
            savedDelay = UserDefaults.standard.double(forKey: "CryptoAtoll_AutoCollapseDelay")
        }
        if savedDelay <= 0 {
            savedDelay = UserDefaults.standard.double(forKey: "CryptoIsland_AutoCollapseDelay")
        }
        self.autoCollapseDelay = savedDelay > 0 ? savedDelay : 1.2

        let hotkey = UserDefaults.standard.object(forKey: "CryptoNotch_HotKeyEnabled") as? Bool
            ?? UserDefaults.standard.object(forKey: "CryptoAtoll_HotKeyEnabled") as? Bool
            ?? (UserDefaults.standard.object(forKey: "CryptoIsland_HotKeyEnabled") as? Bool ?? true)
        self.globalHotKeyEnabled = hotkey

        let savedFavs = UserDefaults.standard.stringArray(forKey: "CryptoNotch_Favorites")
            ?? UserDefaults.standard.stringArray(forKey: "CryptoAtoll_Favorites")
            ?? UserDefaults.standard.stringArray(forKey: "CryptoIsland_Favorites")
            ?? []
        let oldDefaults = ["BTCUSDT", "ETHUSDT", "SOLUSDT", "ARBUSDT", "DOGEUSDT", "PEPEUSDT"]
        if savedFavs == oldDefaults {
            self.favorites = []
            UserDefaults.standard.set([], forKey: "CryptoNotch_Favorites")
        } else {
            self.favorites = savedFavs
        }

        let oldDefaultsV1 = ["24h_high", "24h_low", "vwap", "15m_vol", "5m_vol", "5m_buy_ratio"]
        let savedSlots = UserDefaults.standard.stringArray(forKey: "CryptoNotch_GridSlots")
            ?? UserDefaults.standard.stringArray(forKey: "CryptoAtoll_GridSlots")
            ?? UserDefaults.standard.stringArray(forKey: "CryptoIsland_GridSlots")
            ?? []
        let parsedSlots = savedSlots.compactMap { StatMetric(rawValue: $0) }
        if parsedSlots.count == 6 && savedSlots != oldDefaultsV1 {
            self.gridSlots = parsedSlots
        } else {
            self.gridSlots = StatMetric.defaultSlots
            let raw = StatMetric.defaultSlots.map { $0.rawValue }
            UserDefaults.standard.set(raw, forKey: "CryptoNotch_GridSlots")
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

    public func moveFavorite(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < favorites.count,
              destinationIndex >= 0, destinationIndex < favorites.count,
              sourceIndex != destinationIndex else { return }
        let item = favorites.remove(at: sourceIndex)
        favorites.insert(item, at: destinationIndex)
    }
}
