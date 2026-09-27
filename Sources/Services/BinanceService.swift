import Foundation
import Combine

/// Clean facade orchestrating Binance REST and WebSocket streams for the UI.
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

    private let restClient: BinanceRestClient
    private let streamManager: BinanceStreamManager
    private var fetchTickerTask: Task<Void, Never>?
    private var reconnectTimer: Timer?
    private var flashResetWorkItem: DispatchWorkItem?

    public init(
        initialSymbol: CryptoSymbol? = nil,
        restClient: BinanceRestClient = .shared,
        streamManager: BinanceStreamManager = BinanceStreamManager()
    ) {
        let saved = UserDefaults.standard.string(forKey: "CryptoNotch_SelectedSymbol")
            ?? UserDefaults.standard.string(forKey: "CryptoAtoll_SelectedSymbol")
            ?? UserDefaults.standard.string(forKey: "CryptoIsland_SelectedSymbol")
            ?? "BTCUSDT"
        let symbol = initialSymbol ?? CryptoSymbol.from(rawInput: saved)
        self.currentSymbol = symbol
        self.lastValidSymbol = symbol
        self.restClient = restClient
        self.streamManager = streamManager

        start()
    }

    deinit {
        streamManager.disconnect()
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
        fetchInitialSnapshot()
        connectWebSocket()
    }

    public func restartConnection() {
        fetchTickerTask?.cancel()
        fetchTickerTask = nil
        streamManager.disconnect()
        reconnectTimer?.invalidate()
        isConnected = false
        ticker = nil
        isInvalidSymbol = false
        errorMessage = nil
        
        fetchInitialSnapshot()
        connectWebSocket()
    }

    private func saveSelectedSymbol() {
        UserDefaults.standard.set(currentSymbol.symbol, forKey: "CryptoNotch_SelectedSymbol")
    }

    // MARK: - Initial REST Snapshot Hydration
    private func fetchInitialSnapshot() {
        fetchTickerTask?.cancel()

        let targetSymbol = currentSymbol
        let symbol = targetSymbol.symbol

        fetchTickerTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let json = try await self.restClient.fetch24hTicker(symbol: symbol)
                guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }

                self.isInvalidSymbol = false
                self.errorMessage = nil
                self.lastValidSymbol = targetSymbol
                self.saveSelectedSymbol()

                if let parsed = BinanceDataParser.parseRestTicker(json, symbol: targetSymbol, existing: self.ticker) {
                    self.ticker = parsed
                }
            } catch BinanceRestError.invalidSymbol {
                guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }
                self.handleInvalidSymbol()
                return
            } catch {
                guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }
                if (error as? URLError)?.code != .cancelled {
                    self.errorMessage = "Network connection error"
                }
            }

            guard !Task.isCancelled, !self.isInvalidSymbol, self.currentSymbol.symbol == symbol else { return }

            // Concurrent auxiliary hydration: 5m/15m klines, 1h/4h rolling changes, depth
            async let kline5m = self.restClient.fetchKlineVolume(symbol: symbol, interval: "5m")
            async let kline15m = self.restClient.fetchKlineVolume(symbol: symbol, interval: "15m")
            async let change1h = self.restClient.fetchRollingChange(symbol: symbol, windowSize: "1h")
            async let change4h = self.restClient.fetchRollingChange(symbol: symbol, windowSize: "4h")
            async let depth = self.restClient.fetchDepth(symbol: symbol, limit: 20)

            let (k5, k15, c1, c4, d) = await (kline5m, kline15m, change1h, change4h, depth)
            guard !Task.isCancelled, self.currentSymbol.symbol == symbol else { return }

            if let k5 = k5 {
                self.ticker?.volume5m = k5.volume
                self.ticker?.quoteVolume5m = k5.quoteVolume
                self.ticker?.trades5m = k5.trades
                self.ticker?.takerBuyRatio5m = k5.takerBuyRatio
            }
            if let k15 = k15 {
                self.ticker?.volume15m = k15.volume
                self.ticker?.quoteVolume15m = k15.quoteVolume
                self.ticker?.takerBuyRatio15m = k15.takerBuyRatio
            }
            if let c1 = c1 { self.ticker?.change1h = c1 }
            if let c4 = c4 { self.ticker?.change4h = c4 }
            if let d = d, var current = self.ticker {
                BinanceDataParser.applyDepth(d, to: &current)
                self.ticker = current
            }
        }
    }

    private func handleInvalidSymbol() {
        self.isInvalidSymbol = true
        self.errorMessage = "Coin not found on Binance"
        self.ticker = nil
        self.isConnected = false
        self.streamManager.disconnect()
        self.reconnectTimer?.invalidate()
    }

    // MARK: - WebSocket Streaming
    private func connectWebSocket() {
        guard !isInvalidSymbol else { return }
        reconnectTimer?.invalidate()

        streamManager.connect(
            symbol: currentSymbol.symbol,
            onConnected: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.isConnected = true
                    self?.errorMessage = nil
                }
            },
            onMessage: { [weak self] payloadText in
                Task { @MainActor [weak self] in
                    self?.handleWebSocketMessage(payloadText)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isConnected = false
                    if !self.isInvalidSymbol {
                        if (error as? URLError)?.code != .cancelled && !error.localizedDescription.contains("cancelled") {
                            self.errorMessage = error.localizedDescription
                            self.scheduleReconnect()
                        }
                    }
                }
            }
        )
    }

    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let payload = (json["data"] as? [String: Any]) ?? json
        let stream = (json["stream"] as? String) ?? ""

        if stream.contains("@ticker_1h") {
            if let pStr = payload["P"] as? String, let p = Double(pStr) {
                self.ticker?.change1h = p
            }
        } else if stream.contains("@ticker_4h") {
            if let pStr = payload["P"] as? String, let p = Double(pStr) {
                self.ticker?.change4h = p
            }
        } else if stream.contains("@depth20") {
            if var current = self.ticker {
                BinanceDataParser.applyDepth(payload, to: &current)
                self.ticker = current
            }
        } else if stream.contains("@ticker") || stream.isEmpty {
            if let (newTicker, dir) = BinanceDataParser.parseWebSocketTicker(payload, symbol: currentSymbol, existing: self.ticker) {
                self.ticker = newTicker
                if dir != .neutral {
                    triggerFlash(dir)
                }
            }
        } else if stream.contains("@kline_5m") {
            if var current = self.ticker {
                BinanceDataParser.applyKline(payload, interval: "5m", to: &current)
                self.ticker = current
            }
        } else if stream.contains("@kline_15m") {
            if var current = self.ticker {
                BinanceDataParser.applyKline(payload, interval: "15m", to: &current)
                self.ticker = current
            }
        }
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
