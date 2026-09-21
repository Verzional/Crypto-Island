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

    /// Common presets available out-of-the-box
    public static let presets: [CryptoSymbol] = [
        CryptoSymbol(symbol: "BTCUSDT", baseAsset: "BTC", name: "Bitcoin", iconSymbol: "bitcoinsign.circle.fill"),
        CryptoSymbol(symbol: "ETHUSDT", baseAsset: "ETH", name: "Ethereum", iconSymbol: "e.circle.fill"),
        CryptoSymbol(symbol: "SOLUSDT", baseAsset: "SOL", name: "Solana", iconSymbol: "s.circle.fill"),
        CryptoSymbol(symbol: "BNBUSDT", baseAsset: "BNB", name: "BNB", iconSymbol: "b.circle.fill"),
        CryptoSymbol(symbol: "DOGEUSDT", baseAsset: "DOGE", name: "Dogecoin", iconSymbol: "d.circle.fill"),
        CryptoSymbol(symbol: "XRPUSDT", baseAsset: "XRP", name: "Ripple", iconSymbol: "x.circle.fill"),
        CryptoSymbol(symbol: "SUIUSDT", baseAsset: "SUI", name: "Sui", iconSymbol: "drop.fill"),
        CryptoSymbol(symbol: "ADAUSDT", baseAsset: "ADA", name: "Cardano", iconSymbol: "a.circle.fill"),
        CryptoSymbol(symbol: "PEPEUSDT", baseAsset: "PEPE", name: "Pepe", iconSymbol: "leaf.fill")
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
    public let volume: Double
    public let quoteVolume: Double
    public let lastUpdated: Date
    public var direction: PriceDirection = .neutral

    public init(
        symbol: String,
        price: Double,
        priceChange: Double = 0.0,
        priceChangePercent: Double = 0.0,
        high24h: Double = 0.0,
        low24h: Double = 0.0,
        volume: Double = 0.0,
        quoteVolume: Double = 0.0,
        lastUpdated: Date = Date(),
        direction: PriceDirection = .neutral
    ) {
        self.symbol = symbol
        self.price = price
        self.priceChange = priceChange
        self.priceChangePercent = priceChangePercent
        self.high24h = high24h
        self.low24h = low24h
        self.volume = volume
        self.quoteVolume = quoteVolume
        self.lastUpdated = lastUpdated
        self.direction = direction
    }

    /// Formats price intelligently depending on magnitude
    public var formattedPrice: String {
        if price >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return "$" + (formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price))
        } else if price >= 1 {
            return String(format: "$%.2f", price)
        } else if price >= 0.001 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.6f", price)
        }
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

    public var formattedQuoteVolume: String {
        if quoteVolume >= 1_000_000_000 {
            return String(format: "$%.2fB", quoteVolume / 1_000_000_000)
        } else if quoteVolume >= 1_000_000 {
            return String(format: "$%.2fM", quoteVolume / 1_000_000)
        } else if quoteVolume >= 1_000 {
            return String(format: "$%.1fK", quoteVolume / 1_000)
        } else {
            return String(format: "$%.0f", quoteVolume)
        }
    }

    private func formatPriceValue(_ value: Double) -> String {
        if value >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return "$" + (formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))
        } else if value >= 1 {
            return String(format: "$%.2f", value)
        } else {
            return String(format: "$%.4f", value)
        }
    }
}
