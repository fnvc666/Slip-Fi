//
//  ERC20BalanceService.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 01/08/2025.
//

import Foundation
import SwiftUI

struct ERC20BalanceService {
    static func balanceOfWei(token: String, wallet: String, rpcUrl: String) async throws -> Decimal {
        struct RPCReq: Encodable {
            let jsonrpc = "2.0"
            let id = 1
            let method = "eth_call"
            let params: [AnyEncodable]
        }
        let data = "0x70a08231" + wallet.strip0x().leftPad64()
        let body = RPCReq(params: [AnyEncodable(["to": token, "data": data]), AnyEncodable("latest")])

        var req = URLRequest(url: URL(string: rpcUrl)!)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (resp, _) = try await URLSession.shared.data(for: req)
        guard
            let json = try JSONSerialization.jsonObject(with: resp) as? [String: Any],
            let hex = json["result"] as? String
        else { throw NSError(domain: "balance", code: -1) }

        return Decimal(string: String(UInt64(hex.strip0x(), radix: 16) ?? 0)) ?? 0
    }
}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self._encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

extension String {
    func strip0x() -> String { hasPrefix("0x") ? String(dropFirst(2)) : self }
    func leftPad64() -> String { String(repeating: "0", count: max(0, 64 - count)) + self }
}
