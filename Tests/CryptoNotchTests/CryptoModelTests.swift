import XCTest
@testable import CryptoNotch

final class CryptoModelTests: XCTestCase {
    func testCryptoSymbolFromRawInput() {
        let btc = CryptoSymbol.from(rawInput: "btc")
        XCTAssertEqual(btc.symbol, "BTCUSDT")
        XCTAssertEqual(btc.baseAsset, "BTC")
        XCTAssertEqual(btc.quoteAsset, "USDT")
        XCTAssertEqual(btc.name, "Bitcoin")

        let ethusdt = CryptoSymbol.from(rawInput: "ETHUSDT")
        XCTAssertEqual(ethusdt.symbol, "ETHUSDT")
        XCTAssertEqual(ethusdt.baseAsset, "ETH")

        let custom = CryptoSymbol.from(rawInput: "sol")
        XCTAssertEqual(custom.symbol, "SOLUSDT")
        XCTAssertEqual(custom.baseAsset, "SOL")

        // Input with slash separator
        let slashInput = CryptoSymbol.from(rawInput: "BTC/USDT")
        XCTAssertEqual(slashInput.symbol, "BTCUSDT")
        XCTAssertEqual(slashInput.baseAsset, "BTC")
        XCTAssertEqual(slashInput.quoteAsset, "USDT")

        // Input with currency symbol prefix
        let prefixInput = CryptoSymbol.from(rawInput: "$SOL")
        XCTAssertEqual(prefixInput.symbol, "SOLUSDT")
        XCTAssertEqual(prefixInput.baseAsset, "SOL")

        // Input with dash separator
        let dashInput = CryptoSymbol.from(rawInput: "eth-usdt")
        XCTAssertEqual(dashInput.symbol, "ETHUSDT")
        XCTAssertEqual(dashInput.baseAsset, "ETH")

        // Purely symbols input safely defaults to invalid token
        let invalidSymbols = CryptoSymbol.from(rawInput: "///")
        XCTAssertEqual(invalidSymbols.symbol, "INVALIDUSDT")
        XCTAssertEqual(invalidSymbols.baseAsset, "INVALID")
    }

    func testPriceFormattingStandard() {
        let ticker = TickerData(
            symbol: "BTCUSDT",
            price: 63250.75,
            priceChange: 1250.50,
            priceChangePercent: 2.02
        )
        XCTAssertEqual(ticker.formattedPrice, "$63,250.75")
        XCTAssertEqual(ticker.formattedChangePercent, "+2.02%")
    }

    func testPriceFormattingMicroCap() {
        let ticker = TickerData(
            symbol: "PEPEUSDT",
            price: 0.00000854,
            priceChange: -0.00000012,
            priceChangePercent: -1.38
        )
        XCTAssertEqual(ticker.formattedPrice, "$0.00000854")
        XCTAssertEqual(ticker.formattedChangePercent, "-1.38%")
    }

    func testVolumeFormattingBinanceStyle() {
        let ticker = TickerData(
            symbol: "BTCUSDT",
            price: 60000,
            quoteVolume: 186693.456,
            quoteVolume5m: 1234567.89,
            quoteVolume15m: 2500000000.0
        )
        XCTAssertEqual(ticker.formattedQuoteVolume, "186.693K")
        XCTAssertEqual(ticker.formattedQuoteVolume5m, "1.235M")
        XCTAssertEqual(ticker.formattedQuoteVolume15m, "2.500B")
    }

    @MainActor
    func testSettingsFavoritesTogglingAndCap() {
        let settings = SettingsModel()
        settings.favorites = []

        settings.toggleFavorite("BTC")
        XCTAssertTrue(settings.isFavorite("BTCUSDT"))
        XCTAssertEqual(settings.favorites.count, 1)

        settings.toggleFavorite("BTCUSDT")
        XCTAssertFalse(settings.isFavorite("BTCUSDT"))
        XCTAssertEqual(settings.favorites.count, 0)

        // Test max 9 favorites cap (no auto-discard)
        for i in 1...9 {
            let res = settings.toggleFavorite("COIN\(i)")
            XCTAssertTrue(res)
        }
        XCTAssertEqual(settings.favorites.count, 9)
        XCTAssertTrue(settings.isFavorite("COIN1USDT"))

        // Attempting to add 10th coin should be rejected and not discard COIN1
        let rejected = settings.toggleFavorite("COIN10")
        XCTAssertFalse(rejected)
        XCTAssertEqual(settings.favorites.count, 9)
        XCTAssertTrue(settings.isFavorite("COIN1USDT"))
        XCTAssertFalse(settings.isFavorite("COIN10USDT"))
    }

    func testCryptoSymbolPresetsCount() {
        XCTAssertEqual(CryptoSymbol.presets.count, 9)
        XCTAssertTrue(CryptoSymbol.presets.contains(where: { $0.baseAsset == "BTC" }))
        XCTAssertTrue(CryptoSymbol.presets.contains(where: { $0.baseAsset == "ETH" }))
        XCTAssertTrue(CryptoSymbol.presets.contains(where: { $0.baseAsset == "SOL" }))
    }

    @MainActor
    func testBinanceServiceRevertToLastValidSymbol() {
        let service = BinanceService(initialSymbol: CryptoSymbol.presets[0]) // BTC
        XCTAssertEqual(service.currentSymbol.baseAsset, "BTC")
        
        let eth = CryptoSymbol.presets[1] // ETH
        service.selectSymbol(eth)
        XCTAssertEqual(service.currentSymbol.baseAsset, "ETH")
        
        // When user enters an invalid coin and then reverts:
        service.selectSymbol(CryptoSymbol.from(rawInput: "NONEXISTENT"))
        XCTAssertEqual(service.currentSymbol.baseAsset, "NONEXISTENT")
        
        service.revertToLastValidSymbol()
        XCTAssertEqual(service.currentSymbol.baseAsset, "ETH")
    }

    func testStatMetricCasesAndDefaults() {
        XCTAssertEqual(StatMetric.allCases.count, 22)
        XCTAssertEqual(MetricCategory.allCases.count, 5)
        XCTAssertEqual(StatMetric.defaultSlots.count, 6)
        XCTAssertEqual(StatMetric.defaultSlots, [
            .high24h, .quoteVolume15m, .vwap,
            .low24h, .quoteVolume5m, .takerBuyRatio5m
        ])
        for metric in StatMetric.allCases {
            XCTAssertFalse(metric.title.isEmpty)
            XCTAssertFalse(metric.shortDescription.isEmpty)
            XCTAssertNotEqual(metric.category, .all)
        }
    }

    @MainActor
    func testSettingsGridSlotsCustomizationAndReset() {
        let settings = SettingsModel()
        settings.resetGridSlots()
        XCTAssertEqual(settings.gridSlots.count, 6)
        XCTAssertEqual(settings.gridSlots[0], .high24h)
        XCTAssertEqual(settings.gridSlots[1], .quoteVolume15m)
        XCTAssertEqual(settings.gridSlots[3], .low24h)
        XCTAssertEqual(settings.gridSlots[5], .takerBuyRatio5m)

        // Customizing a slot (e.g. changing slot 5 from takerBuyRatio5m to baseVolume24h)
        settings.updateGridSlot(at: 5, to: .baseVolume24h)
        XCTAssertEqual(settings.gridSlots[5], .baseVolume24h)

        // Customizing slot 0 to trades24h
        settings.updateGridSlot(at: 0, to: .trades24h)
        XCTAssertEqual(settings.gridSlots[0], .trades24h)

        // Customizing slot 2 to bookImbalance
        settings.updateGridSlot(at: 2, to: .bookImbalance)
        XCTAssertEqual(settings.gridSlots[2], .bookImbalance)

        // Out of bounds update should be ignored safely
        settings.updateGridSlot(at: 99, to: .vwap)
        settings.updateGridSlot(at: -1, to: .vwap)
        XCTAssertEqual(settings.gridSlots.count, 6)

        // Reset should restore default slots
        settings.resetGridSlots()
        XCTAssertEqual(settings.gridSlots, StatMetric.defaultSlots)
    }

    func testAdditionalTickerDataFormatters() {
        let ticker = TickerData(
            symbol: "BTCUSDT",
            price: 65000.0,
            priceChange: -1250.0,
            volume: 12500.5,
            quoteVolume: 812500000.0,
            volume15m: 100.0,
            quoteVolume15m: 6500000.0,
            takerBuyRatio15m: 58.4,
            trades24h: 1250000,
            trades5m: 4320,
            bidPrice: 64999.50,
            askPrice: 65000.10,
            change1h: 1.45,
            change4h: -2.30,
            bidDepth20: 3200000.0,
            askDepth20: 2100000.0,
            bookImbalance: 60.38
        )
        XCTAssertEqual(ticker.formattedBaseVolume, "12.501K")
        XCTAssertEqual(ticker.formattedPriceChange, "-$1,250.00")
        XCTAssertEqual(ticker.formattedOpenPrice, "$66,250.00")
        XCTAssertEqual(ticker.formattedTrades24h, "1.25M")
        XCTAssertEqual(ticker.formattedTrades5m, "4.3K")
        XCTAssertEqual(ticker.formattedTakerBuyRatio15m, "58%")
        XCTAssertEqual(ticker.formattedBid, "$64,999.50")
        XCTAssertEqual(ticker.formattedAsk, "$65,000.10")
        XCTAssertEqual(ticker.formattedSpread, "$0.60")
        XCTAssertEqual(ticker.formattedAvgTradeSize, "650.000")
        XCTAssertEqual(ticker.formattedChange1h, "+1.45%")
        XCTAssertEqual(ticker.formattedChange4h, "-2.30%")
        XCTAssertEqual(ticker.formattedBidDepth20, "3.200M")
        XCTAssertEqual(ticker.formattedAskDepth20, "2.100M")
        XCTAssertEqual(ticker.formattedBookImbalance, "60% Bids")
    }
}
