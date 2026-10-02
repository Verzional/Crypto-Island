import SwiftUI

/// Renders a single statistic cell in the expanded island's 2x3 metrics grid.
public struct MetricCellView: View {
    public let slotIndex: Int
    public let metric: StatMetric
    public let ticker: TickerData?

    public init(slotIndex: Int, metric: StatMetric, ticker: TickerData?) {
        self.slotIndex = slotIndex
        self.metric = metric
        self.ticker = ticker
    }

    public var body: some View {
        let info = displayValue(for: metric, ticker: ticker)
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)

            if let val = info.value, !val.isEmpty {
                Text(val)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(info.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: val)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: info.placeholderWidth, height: 12)
                    .skeletonPulse()
                    .padding(.vertical, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buyRatioColor(_ ratio: Double) -> Color {
        if ratio >= 52.0 {
            return .green
        } else if ratio <= 48.0 {
            return .red
        } else {
            return .white.opacity(0.92)
        }
    }

    private func displayValue(for metric: StatMetric, ticker: TickerData?) -> (value: String?, color: Color, placeholderWidth: CGFloat) {
        guard let ticker = ticker else {
            return (nil, .white.opacity(0.92), 52)
        }
        switch metric {
        case .high24h:
            return (ticker.formattedHigh, .white.opacity(0.92), 58)
        case .low24h:
            return (ticker.formattedLow, .white.opacity(0.92), 58)
        case .vwap:
            return (ticker.formattedVWAP, .white.opacity(0.92), 58)
        case .quoteVolume24h:
            return (ticker.formattedQuoteVolume, .white.opacity(0.92), 52)
        case .baseVolume24h:
            return (ticker.formattedBaseVolume, .white.opacity(0.92), 52)
        case .priceChange:
            let color: Color = ticker.priceChange >= 0 ? .green : .red
            return (ticker.formattedPriceChange, color, 52)
        case .openPrice:
            return (ticker.formattedOpenPrice, .white.opacity(0.92), 58)
        case .quoteVolume15m:
            return (ticker.quoteVolume15m > 0 ? ticker.formattedQuoteVolume15m : "--", .white.opacity(0.92), 52)
        case .quoteVolume5m:
            return (ticker.quoteVolume5m > 0 ? ticker.formattedQuoteVolume5m : "--", .white.opacity(0.92), 52)
        case .takerBuyRatio5m:
            let volLoaded = ticker.quoteVolume5m > 0
            let ratio = ticker.takerBuyRatio5m
            return (volLoaded ? ticker.formattedTakerBuyRatio5m : "--", buyRatioColor(ratio), 36)
        case .takerBuyRatio15m:
            let volLoaded = ticker.quoteVolume15m > 0
            let ratio = ticker.takerBuyRatio15m
            return (volLoaded ? ticker.formattedTakerBuyRatio15m : "--", buyRatioColor(ratio), 36)
        case .trades24h:
            return (ticker.trades24h > 0 ? ticker.formattedTrades24h : "--", .white.opacity(0.92), 48)
        case .trades5m:
            return (ticker.trades5m > 0 ? ticker.formattedTrades5m : "--", .white.opacity(0.92), 42)
        case .spread:
            return (ticker.spread > 0 ? ticker.formattedSpread : "--", .white.opacity(0.92), 48)
        case .bestBid:
            return (ticker.bidPrice > 0 ? ticker.formattedBid : "--", .green.opacity(0.92), 54)
        case .bestAsk:
            return (ticker.askPrice > 0 ? ticker.formattedAsk : "--", .red.opacity(0.92), 54)
        case .avgTradeSize:
            let loaded = ticker.trades24h > 0 && ticker.quoteVolume > 0
            return (loaded ? ticker.formattedAvgTradeSize : "--", .white.opacity(0.92), 52)
        case .change1h:
            let color: Color = ticker.change1h >= 0 ? .green : .red
            return (ticker.change1h != 0 ? ticker.formattedChange1h : "--", color, 48)
        case .change4h:
            let color: Color = ticker.change4h >= 0 ? .green : .red
            return (ticker.change4h != 0 ? ticker.formattedChange4h : "--", color, 48)
        case .bookImbalance:
            let loaded = ticker.bidDepth20 > 0 || ticker.askDepth20 > 0
            let color: Color = ticker.bookImbalance >= 52.0 ? .green : (ticker.bookImbalance <= 48.0 ? .red : .white.opacity(0.92))
            return (loaded ? ticker.formattedBookImbalance : "--", color, 52)
        case .bidDepth20:
            return (ticker.bidDepth20 > 0 ? ticker.formattedBidDepth20 : "--", .green.opacity(0.92), 52)
        case .askDepth20:
            return (ticker.askDepth20 > 0 ? ticker.formattedAskDepth20 : "--", .red.opacity(0.92), 52)
        }
    }
}
