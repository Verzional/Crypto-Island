import XCTest
@testable import CryptoIsland

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
}
