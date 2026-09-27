import Foundation

public enum BinanceRestError: Error {
    case invalidSymbol
    case invalidResponse(statusCode: Int)
    case networkError(String)
}

/// Asynchronous HTTP client for Binance Spot Vision REST API.
public final class BinanceRestClient {
    public static let shared = BinanceRestClient()

    private let primaryRestBase = "https://data-api.binance.vision/api/v3"
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            config.timeoutIntervalForRequest = 10
            self.session = URLSession(configuration: config)
        }
    }

    public func fetch24hTicker(symbol: String) async throws -> [String: Any] {
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/ticker/24hr?symbol=\(encodedSymbol)") else {
            throw BinanceRestError.invalidSymbol
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BinanceRestError.invalidSymbol
        }

        if httpResponse.statusCode >= 400 && httpResponse.statusCode < 500 {
            throw BinanceRestError.invalidSymbol
        }

        guard httpResponse.statusCode == 200 else {
            throw BinanceRestError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BinanceRestError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        if let code = json["code"] as? Int, code < 0 {
            throw BinanceRestError.invalidSymbol
        }

        return json
    }

    public func fetchKlineVolume(symbol: String, interval: String) async -> (volume: Double, quoteVolume: Double, trades: Int, takerBuyRatio: Double)? {
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/klines?symbol=\(encodedSymbol)&interval=\(interval)&limit=1") else {
            return nil
        }

        guard let (data, _) = try? await session.data(from: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
              let first = arr.first, first.count > 7 else {
            return nil
        }

        let v = Double(first[5] as? String ?? "0") ?? 0
        let q = Double(first[7] as? String ?? "0") ?? 0
        let trades = first.count > 8 ? (first[8] as? Int ?? 0) : 0
        let tbq = first.count > 10 ? (Double(first[10] as? String ?? "0") ?? 0) : 0
        let ratio = q > 0 ? (tbq / q) * 100 : 50.0

        return (v, q, trades, ratio)
    }

    public func fetchRollingChange(symbol: String, windowSize: String) async -> Double? {
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/ticker?symbol=\(encodedSymbol)&windowSize=\(windowSize)") else {
            return nil
        }

        guard let (data, _) = try? await session.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let pStr = json["priceChangePercent"] as? String, let p = Double(pStr) {
            return p
        }
        return nil
    }

    public func fetchDepth(symbol: String, limit: Int = 20) async -> [String: Any]? {
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(primaryRestBase)/depth?symbol=\(encodedSymbol)&limit=\(limit)") else {
            return nil
        }

        guard let (data, _) = try? await session.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }
}
