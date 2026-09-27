import Foundation

/// Manages the low-latency WebSocket connection to Binance Vision stream endpoints.
public final class BinanceStreamManager {
    private let primaryWsBase = "wss://data-stream.binance.vision:9443"
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession

    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            self.session = URLSession(configuration: config)
        }
    }

    public func connect(
        symbol: String,
        onConnected: @escaping () -> Void,
        onMessage: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        disconnect()

        let symbolLower = symbol.lowercased()
        let streamPath = "\(primaryWsBase)/stream?streams=\(symbolLower)@ticker/\(symbolLower)@ticker_1h/\(symbolLower)@ticker_4h/\(symbolLower)@kline_5m/\(symbolLower)@kline_15m/\(symbolLower)@depth20@1000ms"
        guard let url = URL(string: streamPath) else { return }

        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        listen(for: task, onConnected: onConnected, onMessage: onMessage, onError: onError)
    }

    public func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
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
                onConnected()
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
