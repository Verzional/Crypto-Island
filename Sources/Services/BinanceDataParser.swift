import Foundation

/// Pure functional parser for Binance REST and WebSocket JSON payloads.
public enum BinanceDataParser {

    public static func parseRestTicker(
        _ json: [String: Any],
        symbol: CryptoSymbol,
        existing: TickerData?
    ) -> TickerData? {
        guard let lastPriceStr = json["lastPrice"] as? String,
              let lastPrice = Double(lastPriceStr) else { return nil }

        let priceChange = Double(json["priceChange"] as? String ?? "0") ?? 0
        let priceChangePercent = Double(json["priceChangePercent"] as? String ?? "0") ?? 0
        let high = Double(json["highPrice"] as? String ?? "0") ?? 0
        let low = Double(json["lowPrice"] as? String ?? "0") ?? 0
        let vwap = Double(json["weightedAvgPrice"] as? String ?? "0") ?? 0
        let volume = Double(json["volume"] as? String ?? "0") ?? 0
        let quoteVolume = Double(json["quoteVolume"] as? String ?? "0") ?? 0
        let trades24h = json["count"] as? Int ?? 0
        let bidPrice = Double(json["bidPrice"] as? String ?? "0") ?? 0
        let askPrice = Double(json["askPrice"] as? String ?? "0") ?? 0

        let currentChange1h = existing?.change1h ?? 0
        let currentChange4h = existing?.change4h ?? 0
        let currentBidDepth20 = existing?.bidDepth20 ?? 0
        let currentAskDepth20 = existing?.askDepth20 ?? 0
        let currentBookImbalance = existing?.bookImbalance ?? 50.0

        return TickerData(
            symbol: symbol.symbol,
            price: lastPrice,
            priceChange: priceChange,
            priceChangePercent: priceChangePercent,
            high24h: high,
            low24h: low,
            vwap: vwap,
            volume: volume,
            quoteVolume: quoteVolume,
            trades24h: trades24h,
            bidPrice: bidPrice,
            askPrice: askPrice,
            change1h: currentChange1h,
            change4h: currentChange4h,
            bidDepth20: currentBidDepth20,
            askDepth20: currentAskDepth20,
            bookImbalance: currentBookImbalance,
            lastUpdated: Date(),
            direction: .neutral
        )
    }

    public static func parseWebSocketTicker(
        _ json: [String: Any],
        symbol: CryptoSymbol,
        existing: TickerData?
    ) -> (ticker: TickerData, direction: PriceDirection)? {
        guard let closePriceStr = json["c"] as? String,
              let closePrice = Double(closePriceStr) else { return nil }

        let priceChange = Double(json["p"] as? String ?? "0") ?? 0
        let priceChangePercent = Double(json["P"] as? String ?? "0") ?? 0
        let high = Double(json["h"] as? String ?? "0") ?? 0
        let low = Double(json["l"] as? String ?? "0") ?? 0
        let vwap = Double(json["w"] as? String ?? "0") ?? (existing?.vwap ?? 0)
        let volume = Double(json["v"] as? String ?? "0") ?? 0
        let quoteVolume = Double(json["q"] as? String ?? "0") ?? 0
        let trades24h = json["n"] as? Int ?? (existing?.trades24h ?? 0)
        let bidPrice = Double(json["b"] as? String ?? "0") ?? (existing?.bidPrice ?? 0)
        let askPrice = Double(json["a"] as? String ?? "0") ?? (existing?.askPrice ?? 0)

        var direction: PriceDirection = .neutral
        if let oldPrice = existing?.price {
            if closePrice > oldPrice {
                direction = .up
            } else if closePrice < oldPrice {
                direction = .down
            }
        }

        let current5m = existing?.volume5m ?? 0
        let currentQuote5m = existing?.quoteVolume5m ?? 0
        let currentTakerBuyRatio5m = existing?.takerBuyRatio5m ?? 50.0
        let currentTrades5m = existing?.trades5m ?? 0
        let current15m = existing?.volume15m ?? 0
        let currentQuote15m = existing?.quoteVolume15m ?? 0
        let currentTakerBuyRatio15m = existing?.takerBuyRatio15m ?? 50.0
        let currentChange1h = existing?.change1h ?? 0
        let currentChange4h = existing?.change4h ?? 0
        let currentBidDepth20 = existing?.bidDepth20 ?? 0
        let currentAskDepth20 = existing?.askDepth20 ?? 0
        let currentBookImbalance = existing?.bookImbalance ?? 50.0

        let ticker = TickerData(
            symbol: symbol.symbol,
            price: closePrice,
            priceChange: priceChange,
            priceChangePercent: priceChangePercent,
            high24h: high,
            low24h: low,
            vwap: vwap,
            volume: volume,
            quoteVolume: quoteVolume,
            volume5m: current5m,
            quoteVolume5m: currentQuote5m,
            takerBuyRatio5m: currentTakerBuyRatio5m,
            volume15m: current15m,
            quoteVolume15m: currentQuote15m,
            takerBuyRatio15m: currentTakerBuyRatio15m,
            trades24h: trades24h,
            trades5m: currentTrades5m,
            bidPrice: bidPrice,
            askPrice: askPrice,
            change1h: currentChange1h,
            change4h: currentChange4h,
            bidDepth20: currentBidDepth20,
            askDepth20: currentAskDepth20,
            bookImbalance: currentBookImbalance,
            lastUpdated: Date(),
            direction: direction
        )
        return (ticker, direction)
    }

    public static func applyKline(
        _ json: [String: Any],
        interval: String,
        to ticker: inout TickerData
    ) {
        guard let k = json["k"] as? [String: Any],
              let vStr = k["v"] as? String, let v = Double(vStr),
              let qStr = k["q"] as? String, let q = Double(qStr) else { return }

        let tbqStr = k["Q"] as? String
        let tbq = Double(tbqStr ?? "0") ?? 0
        let trades = k["n"] as? Int ?? 0

        if interval == "5m" {
            ticker.volume5m = v
            ticker.quoteVolume5m = q
            ticker.takerBuyRatio5m = q > 0 ? (tbq / q) * 100 : 50.0
            ticker.trades5m = trades
        } else if interval == "15m" {
            ticker.volume15m = v
            ticker.quoteVolume15m = q
            ticker.takerBuyRatio15m = q > 0 ? (tbq / q) * 100 : 50.0
        }
    }

    public static func applyDepth(
        _ json: [String: Any],
        to ticker: inout TickerData
    ) {
        guard let bids = json["bids"] as? [[Any]],
              let asks = json["asks"] as? [[Any]] else { return }

        var totalBidDepth: Double = 0
        for bid in bids {
            guard bid.count >= 2 else { continue }
            let p = (bid[0] as? Double) ?? Double(bid[0] as? String ?? "") ?? 0
            let q = (bid[1] as? Double) ?? Double(bid[1] as? String ?? "") ?? 0
            totalBidDepth += (p * q)
        }

        var totalAskDepth: Double = 0
        for ask in asks {
            guard ask.count >= 2 else { continue }
            let p = (ask[0] as? Double) ?? Double(ask[0] as? String ?? "") ?? 0
            let q = (ask[1] as? Double) ?? Double(ask[1] as? String ?? "") ?? 0
            totalAskDepth += (p * q)
        }

        ticker.bidDepth20 = totalBidDepth
        ticker.askDepth20 = totalAskDepth

        let combined = totalBidDepth + totalAskDepth
        if combined > 0 {
            ticker.bookImbalance = (totalBidDepth / combined) * 100.0
        }
    }
}
