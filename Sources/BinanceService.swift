import Foundation
import Combine

/// Manages real-time cryptocurrency data streaming from Binance via WebSocket and REST API.
@MainActor
public final class BinanceService: ObservableObject {
    @Published public var currentSymbol: CryptoSymbol {
        didSet {
            if oldValue.symbol != currentSymbol.symbol {
                restartConnection()
            }
        }
    }
    
    @Published public private(set) var ticker: TickerData?
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var flashDirection: PriceDirection?
    @Published public private(set) var isInvalidSymbol: Bool = false
    private var lastValidSymbol: CryptoSymbol

    // Network & Endpoints (Binance Vision unblocked public cluster)
    private let primaryWsBase = "wss://data-stream.binance.vision:9443"
    private let primaryRestBase = "https://data-api.binance.vision/api/v3"

    private var webSocketTask: URLSessionWebSocketTask?
    private var fetchTickerTask: Task<Void, Never>?
    private var session: URLSession
    private var reconnectTimer: Timer?
    private var flashResetWorkItem: DispatchWorkItem?

    public init(initialSymbol: CryptoSymbol? = nil) {
        let saved = UserDefaults.standard.string(forKey: "CryptoIsland_SelectedSymbol") ?? "BTCUSDT"
        let symbol = initialSymbol ?? CryptoSymbol.from(rawInput: saved)
        self.currentSymbol = symbol
        self.lastValidSymbol = symbol
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)

        start()
    }

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        reconnectTimer?.invalidate()
    }

    public func selectSymbol(_ symbol: CryptoSymbol) {
        guard symbol.symbol != currentSymbol.symbol else { return }
        if !isInvalidSymbol && (ticker != nil || CryptoSymbol.presets.contains(where: { $0.symbol == currentSymbol.symbol })) {
            lastValidSymbol = currentSymbol
        }
        isInvalidSymbol = false
        errorMessage = nil
        currentSymbol = symbol
    }

    public func revertToLastValidSymbol() {
        let target: CryptoSymbol
        if lastValidSymbol.symbol != currentSymbol.symbol {
            target = lastValidSymbol
        } else if let fallback = CryptoSymbol.presets.first(where: { $0.symbol != currentSymbol.symbol }) {
            target = fallback
        } else {
            target = CryptoSymbol.presets[0]
        }
        selectSymbol(target)
    }

    public func start() {
        fetchInitialTicker()
        connectWebSocket()
    }

    public func restartConnection() {
        fetchTickerTask?.cancel()
        fetchTickerTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        ticker = nil
        isInvalidSymbol = false
        errorMessage = nil
        
        fetchInitialTicker()
        connectWebSocket()
    }

    private func saveSelectedSymbol() {
        UserDefaults.standard.set(currentSymbol.symbol, forKey: "CryptoIsland_SelectedSymbol")
    }

    // MARK: - REST Initial Fetch
    private func fetchInitialTicker() {
        fetchTickerTask?.cancel()

        let targetSymbol = currentSymbol
        let symbol = targetSymbol.symbol
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/ticker/24hr?symbol=\(encodedSymbol)") else {
            handleInvalidSymbol()
            return
        }

        fetchTickerTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let (data, response) = try await self.session.data(from: url)
                guard !Task.isCancelled else { return }
                guard self.currentSymbol.symbol == symbol else { return }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.handleInvalidSymbol()
                    return
                }

                // Any 4xx client error (400 bad request, 404 not found) indicates an invalid/unsupported symbol
                if httpResponse.statusCode >= 400 && httpResponse.statusCode < 500 {
                    self.handleInvalidSymbol()
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    self.errorMessage = "Service temporarily unavailable (\(httpResponse.statusCode))"
                    return
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let code = json["code"] as? Int, code < 0 {
                        self.handleInvalidSymbol()
                        return
                    }
                    self.isInvalidSymbol = false
                    self.errorMessage = nil
                    self.lastValidSymbol = targetSymbol
                    self.saveSelectedSymbol()
                    self.processRestTicker(json)
                }
            } catch {
                guard !Task.isCancelled else { return }
                guard self.currentSymbol.symbol == symbol else { return }
                if (error as? URLError)?.code == .cancelled { return }

                self.errorMessage = "Network connection error"
            }

            guard !Task.isCancelled, !self.isInvalidSymbol, self.currentSymbol.symbol == symbol else { return }
            // Fetch initial 5m and 15m kline volume, 1h & 4h tickers, and depth
            await self.fetchInitialKlineVolume(interval: "5m")
            await self.fetchInitialKlineVolume(interval: "15m")
            await self.fetchInitial1hTicker()
            await self.fetchInitial4hTicker()
            await self.fetchInitialDepth()
        }
    }

    private func handleInvalidSymbol() {
        self.isInvalidSymbol = true
        self.errorMessage = "Coin not found on Binance"
        self.ticker = nil
        self.isConnected = false
        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.webSocketTask = nil
        self.reconnectTimer?.invalidate()
    }

    private func fetchInitialKlineVolume(interval: String) async {
        let symbol = currentSymbol.symbol
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/klines?symbol=\(encodedSymbol)&interval=\(interval)&limit=1") else { return }

        if let (data, _) = try? await session.data(from: url),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
           let first = arr.first, first.count > 7 {
            guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }
            let v = Double(first[5] as? String ?? "0") ?? 0
            let q = Double(first[7] as? String ?? "0") ?? 0
            let trades = first.count > 8 ? (first[8] as? Int ?? 0) : 0
            let tbq = first.count > 10 ? (Double(first[10] as? String ?? "0") ?? 0) : 0
            if interval == "5m" {
                self.ticker?.volume5m = v
                self.ticker?.quoteVolume5m = q
                self.ticker?.takerBuyRatio5m = q > 0 ? (tbq / q) * 100 : 50.0
                self.ticker?.trades5m = trades
            } else if interval == "15m" {
                self.ticker?.volume15m = v
                self.ticker?.quoteVolume15m = q
                self.ticker?.takerBuyRatio15m = q > 0 ? (tbq / q) * 100 : 50.0
            }
        }
    }

    private func fetchInitial1hTicker() async {
        let symbol = currentSymbol.symbol
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/ticker?symbol=\(encodedSymbol)&windowSize=1h") else { return }

        if let (data, _) = try? await session.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }
            if let pStr = json["priceChangePercent"] as? String, let p = Double(pStr) {
                self.ticker?.change1h = p
            }
        }
    }

    private func fetchInitial4hTicker() async {
        let symbol = currentSymbol.symbol
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/ticker?symbol=\(encodedSymbol)&windowSize=4h") else { return }

        if let (data, _) = try? await session.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }
            if let pStr = json["priceChangePercent"] as? String, let p = Double(pStr) {
                self.ticker?.change4h = p
            }
        }
    }

    private func fetchInitialDepth() async {
        let symbol = currentSymbol.symbol
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/depth?symbol=\(encodedSymbol)&limit=20") else { return }

        if let (data, _) = try? await session.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }
            self.handleDepthData(json)
        }
    }

    private func processRestTicker(_ json: [String: Any]) {
        guard let lastPriceStr = json["lastPrice"] as? String,
              let lastPrice = Double(lastPriceStr) else { return }

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

        let currentChange1h = self.ticker?.change1h ?? 0
        let currentChange4h = self.ticker?.change4h ?? 0
        let currentBidDepth20 = self.ticker?.bidDepth20 ?? 0
        let currentAskDepth20 = self.ticker?.askDepth20 ?? 0
        let currentBookImbalance = self.ticker?.bookImbalance ?? 50.0

        self.ticker = TickerData(
            symbol: currentSymbol.symbol,
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

    // MARK: - WebSocket Live Streaming
    private func connectWebSocket() {
        guard !isInvalidSymbol else { return }
        reconnectTimer?.invalidate()
        let symbolLower = currentSymbol.symbol.lowercased()
        let streamPath = "\(primaryWsBase)/stream?streams=\(symbolLower)@ticker/\(symbolLower)@ticker_1h/\(symbolLower)@ticker_4h/\(symbolLower)@kline_5m/\(symbolLower)@kline_15m/\(symbolLower)@depth20@1000ms"
        guard let url = URL(string: streamPath) else { return }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        listenForMessages()
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    self.isConnected = true
                    self.errorMessage = nil
                    switch message {
                    case .string(let text):
                        self.handleWebSocketPayload(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleWebSocketPayload(text)
                        }
                    @unknown default:
                        break
                    }
                    self.listenForMessages()

                case .failure(let error):
                    self.isConnected = false
                    if !self.isInvalidSymbol {
                        if (error as? URLError)?.code != .cancelled && !error.localizedDescription.contains("cancelled") {
                            self.errorMessage = error.localizedDescription
                            self.scheduleReconnect()
                        }
                    }
                }
            }
        }
    }

    private func handleWebSocketPayload(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let stream = json["stream"] as? String, let payload = json["data"] as? [String: Any] {
            if stream.contains("@ticker_1h") {
                handle1hTicker(payload)
            } else if stream.contains("@ticker_4h") {
                handle4hTicker(payload)
            } else if stream.contains("@depth20") {
                handleDepthData(payload)
            } else if stream.contains("@ticker") {
                handleTickerData(payload)
            } else if stream.contains("@kline_5m") {
                handleKlineData(payload, interval: "5m")
            } else if stream.contains("@kline_15m") {
                handleKlineData(payload, interval: "15m")
            }
        } else {
            handleTickerData(json)
        }
    }

    private func handle1hTicker(_ json: [String: Any]) {
        if let pStr = json["P"] as? String, let p = Double(pStr) {
            self.ticker?.change1h = p
        }
    }

    private func handle4hTicker(_ json: [String: Any]) {
        if let pStr = json["P"] as? String, let p = Double(pStr) {
            self.ticker?.change4h = p
        }
    }

    private func handleDepthData(_ json: [String: Any]) {
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

        self.ticker?.bidDepth20 = totalBidDepth
        self.ticker?.askDepth20 = totalAskDepth

        let combined = totalBidDepth + totalAskDepth
        if combined > 0 {
            self.ticker?.bookImbalance = (totalBidDepth / combined) * 100.0
        }
    }

    private func handleKlineData(_ json: [String: Any], interval: String) {
        guard let k = json["k"] as? [String: Any],
              let vStr = k["v"] as? String, let v = Double(vStr),
              let qStr = k["q"] as? String, let q = Double(qStr) else { return }

        let tbqStr = k["Q"] as? String
        let tbq = Double(tbqStr ?? "0") ?? 0
        let trades = k["n"] as? Int ?? 0

        if interval == "5m" {
            self.ticker?.volume5m = v
            self.ticker?.quoteVolume5m = q
            self.ticker?.takerBuyRatio5m = q > 0 ? (tbq / q) * 100 : 50.0
            self.ticker?.trades5m = trades
        } else if interval == "15m" {
            self.ticker?.volume15m = v
            self.ticker?.quoteVolume15m = q
            self.ticker?.takerBuyRatio15m = q > 0 ? (tbq / q) * 100 : 50.0
        }
    }

    private func handleTickerData(_ json: [String: Any]) {
        guard let closePriceStr = json["c"] as? String,
              let closePrice = Double(closePriceStr) else { return }

        let priceChange = Double(json["p"] as? String ?? "0") ?? 0
        let priceChangePercent = Double(json["P"] as? String ?? "0") ?? 0
        let high = Double(json["h"] as? String ?? "0") ?? 0
        let low = Double(json["l"] as? String ?? "0") ?? 0
        let vwap = Double(json["w"] as? String ?? "0") ?? (self.ticker?.vwap ?? 0)
        let volume = Double(json["v"] as? String ?? "0") ?? 0
        let quoteVolume = Double(json["q"] as? String ?? "0") ?? 0
        let trades24h = json["n"] as? Int ?? (self.ticker?.trades24h ?? 0)
        let bidPrice = Double(json["b"] as? String ?? "0") ?? (self.ticker?.bidPrice ?? 0)
        let askPrice = Double(json["a"] as? String ?? "0") ?? (self.ticker?.askPrice ?? 0)

        var direction: PriceDirection = .neutral
        if let oldPrice = self.ticker?.price {
            if closePrice > oldPrice {
                direction = .up
                triggerFlash(.up)
            } else if closePrice < oldPrice {
                direction = .down
                triggerFlash(.down)
            }
        }

        let current5m = self.ticker?.volume5m ?? 0
        let currentQuote5m = self.ticker?.quoteVolume5m ?? 0
        let currentTakerBuyRatio5m = self.ticker?.takerBuyRatio5m ?? 50.0
        let currentTrades5m = self.ticker?.trades5m ?? 0
        let current15m = self.ticker?.volume15m ?? 0
        let currentQuote15m = self.ticker?.quoteVolume15m ?? 0
        let currentTakerBuyRatio15m = self.ticker?.takerBuyRatio15m ?? 50.0
        let currentChange1h = self.ticker?.change1h ?? 0
        let currentChange4h = self.ticker?.change4h ?? 0
        let currentBidDepth20 = self.ticker?.bidDepth20 ?? 0
        let currentAskDepth20 = self.ticker?.askDepth20 ?? 0
        let currentBookImbalance = self.ticker?.bookImbalance ?? 50.0

        self.ticker = TickerData(
            symbol: currentSymbol.symbol,
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
    }

    private func triggerFlash(_ direction: PriceDirection) {
        flashResetWorkItem?.cancel()
        flashDirection = direction

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.flashDirection = nil
            }
        }
        flashResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: workItem)
    }

    private func scheduleReconnect() {
        guard !isInvalidSymbol else { return }
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isInvalidSymbol else { return }
                self.connectWebSocket()
            }
        }
    }
}
