//
//  OneInchHTTPClient.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 26/07/2025.
//
import SwiftUI

final class OneInchHTTPClient {
    private let session = URLSession.shared
    private let base = URL(string: "https://api.1inch.dev")!
    private let key = Secrets.oneInchKey

    struct APIError: Decodable, Error { let statusCode: Int?; let error: String?; let message: String? }

    func get<T: Decodable>(_ path: String, q: [String:String]) async throws -> T {
        guard !key.isEmpty else { throw NSError(domain: "oneinch", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing ONEINCH_API_KEY"]) }

        var comp = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comp.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) }

        var req = URLRequest(url: comp.url!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await session.data(for: req)
        let http = resp as! HTTPURLResponse

        #if DEBUG
        print("GET \(comp.url!.absoluteString) → \(http.statusCode)")
        if !(200...299).contains(http.statusCode) {
            print(String(data: data, encoding: .utf8) ?? "<no body>")
        }
        #endif

        guard (200...299).contains(http.statusCode) else {
            if let apiErr = try? JSONDecoder().decode(APIError.self, from: data) {
                let msg = apiErr.message ?? apiErr.error ?? "HTTP \(http.statusCode)"
                throw NSError(domain: "oneinch", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "oneinch", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}


extension Secrets {
    static let oneInchKey = value(for: "OneInchApiKey")
}

