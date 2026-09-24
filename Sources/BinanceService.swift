import Foundation
import Combine

/// Manages real-time cryptocurrency data streaming from Binance via WebSocket and REST API.
@MainActor
public final class BinanceService: ObservableObject {
    @Published public var currentSymbol: CryptoSymbol {
        didSet {
            if oldValue.symbol != currentSymbol.symbol {
                saveSelectedSymbol()
                restartConnection()
            }
        }
    }
    
    @Published public private(set) var ticker: TickerData?
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var flashDirection: PriceDirection?

    // Network & Endpoints
    private let primaryWsBase = "wss://data-stream.binance.vision:9443"
    private let fallbackWsBase = "wss://stream.binance.com:9443"
    private let primaryRestBase = "https://data-api.binance.vision/api/v3"
    private let fallbackRestBase = "https://api.binance.com/api/v3"

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var reconnectTimer: Timer?
    private var flashResetWorkItem: DispatchWorkItem?
    private var useFallback: Bool = false

    public init(initialSymbol: CryptoSymbol? = nil) {
        let saved = UserDefaults.standard.string(forKey: "CryptoIsland_SelectedSymbol") ?? "BTCUSDT"
        let symbol = initialSymbol ?? CryptoSymbol.from(rawInput: saved)
        self.currentSymbol = symbol
        
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
        currentSymbol = symbol
    }

    public func start() {
        fetchInitialTicker()
        connectWebSocket()
    }

    public func restartConnection() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        ticker = nil
        
        fetchInitialTicker()
        connectWebSocket()
    }

    private func saveSelectedSymbol() {
        UserDefaults.standard.set(currentSymbol.symbol, forKey: "CryptoIsland_SelectedSymbol")
    }

    // MARK: - REST Fallback / Initial Fetch
    private func fetchInitialTicker() {
        let symbol = currentSymbol.symbol
        let baseUrl = useFallback ? fallbackRestBase : primaryRestBase
        guard let url = URL(string: "\(baseUrl)/ticker/24hr?symbol=\(symbol)") else { return }

        Task {
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    if !useFallback {
                        useFallback = true
                        fetchInitialTicker()
                    }
                    return
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.processRestTicker(json)
                }
            } catch {
                if !useFallback {
                    useFallback = true
                    fetchInitialTicker()
                }
            }

            // Fetch initial 5m and 15m kline volume
            await fetchInitialKlineVolume(interval: "5m")
            await fetchInitialKlineVolume(interval: "15m")
        }
    }

    private func fetchInitialKlineVolume(interval: String) async {
        let symbol = currentSymbol.symbol
        let baseUrl = useFallback ? fallbackRestBase : primaryRestBase
        guard let url = URL(string: "\(baseUrl)/klines?symbol=\(symbol)&interval=\(interval)&limit=1") else { return }

        if let (data, _) = try? await session.data(from: url),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
           let first = arr.first, first.count > 7 {
            let v = Double(first[5] as? String ?? "0") ?? 0
            let q = Double(first[7] as? String ?? "0") ?? 0
            let tbq = first.count > 10 ? (Double(first[10] as? String ?? "0") ?? 0) : 0
            if interval == "5m" {
                self.ticker?.volume5m = v
                self.ticker?.quoteVolume5m = q
                self.ticker?.takerBuyRatio5m = q > 0 ? (tbq / q) * 100 : 50.0
            } else if interval == "15m" {
                self.ticker?.volume15m = v
                self.ticker?.quoteVolume15m = q
            }
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
            lastUpdated: Date(),
            direction: .neutral
        )
    }

    // MARK: - WebSocket Live Streaming
    private func connectWebSocket() {
        reconnectTimer?.invalidate()
        let symbolLower = currentSymbol.symbol.lowercased()
        let wsBase = useFallback ? fallbackWsBase : primaryWsBase
        let streamPath = "\(wsBase)/stream?streams=\(symbolLower)@ticker/\(symbolLower)@kline_5m/\(symbolLower)@kline_15m"
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
                    self.errorMessage = error.localizedDescription
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleWebSocketPayload(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let stream = json["stream"] as? String, let payload = json["data"] as? [String: Any] {
            if stream.contains("@ticker") {
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

    private func handleKlineData(_ json: [String: Any], interval: String) {
        guard let k = json["k"] as? [String: Any],
              let vStr = k["v"] as? String, let v = Double(vStr),
              let qStr = k["q"] as? String, let q = Double(qStr) else { return }

        let tbqStr = k["Q"] as? String
        let tbq = Double(tbqStr ?? "0") ?? 0

        if interval == "5m" {
            self.ticker?.volume5m = v
            self.ticker?.quoteVolume5m = q
            self.ticker?.takerBuyRatio5m = q > 0 ? (tbq / q) * 100 : 50.0
        } else if interval == "15m" {
            self.ticker?.volume15m = v
            self.ticker?.quoteVolume15m = q
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
        let current15m = self.ticker?.volume15m ?? 0
        let currentQuote15m = self.ticker?.quoteVolume15m ?? 0

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
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.useFallback.toggle() // Try alternate endpoint if primary disconnected
                self.connectWebSocket()
            }
        }
    }
}
