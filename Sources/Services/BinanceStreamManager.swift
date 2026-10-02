import Foundation

/// Manages the low-latency WebSocket connection to Binance Vision stream endpoints.
public final class BinanceStreamManager {
    private let primaryWsBase = "wss://data-stream.binance.vision:9443"
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var hasReportedConnected: Bool = false
    private var pingTimer: Timer?

    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            config.httpAdditionalHeaders = ["User-Agent": "CryptoNotch/1.1.2"]
            self.session = URLSession(configuration: config)
        }
    }

    public func connect(
        symbol: String,
        exchange: CryptoExchange = .binance,
        onConnected: @escaping () -> Void,
        onMessage: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        disconnect()
        hasReportedConnected = false

        let url: URL
        var subscribeMessage: String? = nil

        switch exchange {
        case .binance:
            let symbolLower = symbol.lowercased()
            let streamPath = "\(primaryWsBase)/stream?streams=\(symbolLower)@ticker/\(symbolLower)@ticker_1h/\(symbolLower)@ticker_4h/\(symbolLower)@kline_5m/\(symbolLower)@kline_15m/\(symbolLower)@depth20@1000ms"
            guard let u = URL(string: streamPath) else { return }
            url = u

        case .coinbase:
            guard let u = URL(string: "wss://ws-feed.exchange.coinbase.com") else { return }
            url = u
            subscribeMessage = "{\"type\":\"subscribe\",\"product_ids\":[\"\(symbol)\"],\"channels\":[\"ticker\"]}"

        case .kraken:
            guard let u = URL(string: "wss://ws.kraken.com/v2") else { return }
            url = u
            subscribeMessage = "{\"method\":\"subscribe\",\"params\":{\"channel\":\"ticker\",\"symbol\":[\"\(symbol)\"]}}"
        }

        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        if let sub = subscribeMessage {
            task.send(.string(sub)) { error in
                if let error = error {
                    onError(error)
                }
            }
        }

        listen(for: task, onConnected: onConnected, onMessage: onMessage, onError: onError)
    }

    public func disconnect() {
        hasReportedConnected = false
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func startPingTimer(for task: URLSessionWebSocketTask) {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak task] _ in
            task?.sendPing { _ in }
        }
    }

    private func listen(
        for task: URLSessionWebSocketTask,
        onConnected: @escaping () -> Void,
        onMessage: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        task.receive { [weak self, weak task] result in
            guard let self = self, let activeTask = task, activeTask === self.webSocketTask else { return }

            switch result {
            case .success(let message):
                if !self.hasReportedConnected {
                    self.hasReportedConnected = true
                    self.startPingTimer(for: activeTask)
                    onConnected()
                }
                switch message {
                case .string(let text):
                    onMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        onMessage(text)
                    }
                @unknown default:
                    break
                }
                self.listen(for: activeTask, onConnected: onConnected, onMessage: onMessage, onError: onError)

            case .failure(let error):
                onError(error)
            }
        }
    }
}
