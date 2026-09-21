import Foundation

/// Represents a cryptocurrency trading pair on Binance.
public struct CryptoSymbol: Identifiable, Hashable, Codable {
    public var id: String { symbol }
    public let symbol: String
    public let baseAsset: String
    public let quoteAsset: String
    public let name: String
    public let iconSymbol: String

    public init(symbol: String, baseAsset: String, quoteAsset: String = "USDT", name: String, iconSymbol: String) {
        self.symbol = symbol.uppercased()
        self.baseAsset = baseAsset.uppercased()
        self.quoteAsset = quoteAsset.uppercased()
        self.name = name
        self.iconSymbol = iconSymbol
    }

    /// Common presets available out-of-the-box (Top 9 non-stablecoin cryptocurrencies)
    public static let presets: [CryptoSymbol] = [
        CryptoSymbol(symbol: "BTCUSDT", baseAsset: "BTC", name: "Bitcoin", iconSymbol: "bitcoinsign.circle.fill"),
        CryptoSymbol(symbol: "ETHUSDT", baseAsset: "ETH", name: "Ethereum", iconSymbol: "e.circle.fill"),
        CryptoSymbol(symbol: "BNBUSDT", baseAsset: "BNB", name: "BNB", iconSymbol: "b.circle.fill"),
        CryptoSymbol(symbol: "XRPUSDT", baseAsset: "XRP", name: "Ripple", iconSymbol: "x.circle.fill"),
        CryptoSymbol(symbol: "SOLUSDT", baseAsset: "SOL", name: "Solana", iconSymbol: "s.circle.fill"),
        CryptoSymbol(symbol: "TRXUSDT", baseAsset: "TRX", name: "TRON", iconSymbol: "t.circle.fill"),
        CryptoSymbol(symbol: "DOGEUSDT", baseAsset: "DOGE", name: "Dogecoin", iconSymbol: "d.circle.fill"),
        CryptoSymbol(symbol: "ADAUSDT", baseAsset: "ADA", name: "Cardano", iconSymbol: "a.circle.fill"),
        CryptoSymbol(symbol: "LINKUSDT", baseAsset: "LINK", name: "Chainlink", iconSymbol: "link.circle.fill")
    ]

    /// Creates a symbol from user text (e.g. "BTC" or "BTCUSDT")
    public static func from(rawInput: String) -> CryptoSymbol {
        var clean = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.isEmpty { clean = "BTCUSDT" }
        
        let quote = "USDT"
        let base: String
        let symbol: String
        
        if clean.hasSuffix(quote) && clean.count > 4 {
            symbol = clean
            base = String(clean.dropLast(quote.count))
        } else {
            base = clean
            symbol = clean + quote
        }

        if let existing = presets.first(where: { $0.symbol == symbol }) {
            return existing
        }

        return CryptoSymbol(
            symbol: symbol,
            baseAsset: base,
            quoteAsset: quote,
            name: base,
            iconSymbol: "circle.fill"
        )
    }
}

/// Price change direction indicator
public enum PriceDirection: Equatable {
    case up
    case down
    case neutral
}

/// Real-time ticker data received from Binance
public struct TickerData: Equatable {
    public let symbol: String
    public let price: Double
    public let priceChange: Double
    public let priceChangePercent: Double
    public let high24h: Double
    public let low24h: Double
    public var vwap: Double
    public let volume: Double
    public let quoteVolume: Double
    public var volume5m: Double
    public var quoteVolume5m: Double
    public var takerBuyRatio5m: Double
    public var volume15m: Double
    public var quoteVolume15m: Double
    public let lastUpdated: Date
    public var direction: PriceDirection = .neutral

    public init(
        symbol: String,
        price: Double,
        priceChange: Double = 0.0,
        priceChangePercent: Double = 0.0,
        high24h: Double = 0.0,
        low24h: Double = 0.0,
        vwap: Double = 0.0,
        volume: Double = 0.0,
        quoteVolume: Double = 0.0,
        volume5m: Double = 0.0,
        quoteVolume5m: Double = 0.0,
        takerBuyRatio5m: Double = 50.0,
        volume15m: Double = 0.0,
        quoteVolume15m: Double = 0.0,
        lastUpdated: Date = Date(),
        direction: PriceDirection = .neutral
    ) {
        self.symbol = symbol
        self.price = price
        self.priceChange = priceChange
        self.priceChangePercent = priceChangePercent
        self.high24h = high24h
        self.low24h = low24h
        self.vwap = vwap
        self.volume = volume
        self.quoteVolume = quoteVolume
        self.volume5m = volume5m
        self.quoteVolume5m = quoteVolume5m
        self.takerBuyRatio5m = takerBuyRatio5m
        self.volume15m = volume15m
        self.quoteVolume15m = quoteVolume15m
        self.lastUpdated = lastUpdated
        self.direction = direction
    }

    /// Formats price intelligently depending on magnitude
    public var formattedPrice: String {
        formatPriceValue(price)
    }

    public var formattedChangePercent: String {
        let prefix = priceChangePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, priceChangePercent)
    }

    public var formattedHigh: String {
        formatPriceValue(high24h)
    }

    public var formattedLow: String {
        formatPriceValue(low24h)
    }

    public var formattedVWAP: String {
        formatPriceValue(vwap)
    }

    public var formattedTakerBuyRatio5m: String {
        guard quoteVolume5m > 0 else { return "--" }
        return String(format: "%.0f%%", takerBuyRatio5m)
    }

    public var formattedQuoteVolume: String {
        formatVolumeValue(quoteVolume)
    }

    public var formattedQuoteVolume5m: String {
        formatVolumeValue(quoteVolume5m)
    }

    public var formattedQuoteVolume15m: String {
        formatVolumeValue(quoteVolume15m)
    }

    private func formatVolumeValue(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.1fK", value / 1_000)
        } else if value > 0 {
            return String(format: "$%.0f", value)
        } else {
            return "--"
        }
    }

    private func formatPriceValue(_ value: Double) -> String {
        guard value > 0 else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if value >= 1000 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        } else if value >= 1 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 4
        } else if value >= 0.01 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 6
        } else {
            // For sub-cent & micro-cap tokens (e.g. PEPE, SHIB) supporting up to 8 decimals
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 8
        }

        if let str = formatter.string(from: NSNumber(value: value)) {
            return "$" + str
        } else {
            return String(format: "$%.8f", value)
        }
    }
}
