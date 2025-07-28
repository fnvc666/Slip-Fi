//
//  QuoteResponse.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import ReownAppKit
import SwiftUI

struct QuoteResponse: Decodable {
//    let fromToken: OneInchToken?
//    let toToken: OneInchToken?
//    let toAmount: String?
//    let fromTokenAmount: String?
//    let estimatedGas: Int?
    let dstAmount: String

        var inWei: String { "1000000" } // ты знаешь, сколько передаешь
        var outWei: String { dstAmount }
        var inDecimals: Int { 6 }
        var outDecimals: Int { 18 }
        var inSymbol: String { "USDC" }
        var outSymbol: String { "WETH" }
    
}

//extension QuoteResponse {
//    var inWei: String { fromTokenAmount ?? "0" }
//    var outWei: String { toAmount ?? "0" }
//
//    var inDecimals: Int  { fromToken?.decimals ?? 6 }
//    var outDecimals: Int { toToken?.decimals ?? 18 }
//    var inSymbol: String { fromToken?.symbol ?? "USDC" }
//    var outSymbol: String { toToken?.symbol ?? "WETH" }
//}


struct OneInchToken: Decodable {
    let symbol: String
    let name: String
    let address: String
    let decimals: Int
    let logoURI: String?
}

protocol QuoteService {
    func quote(from: String, to: String, amountWei: String, chain: Chain) async throws -> QuoteResponse
}

final class OneInchQuoteService: QuoteService {
    private let client = OneInchHTTPClient()
    func quote(from: String, to: String, amountWei: String, chain: Chain) async throws -> QuoteResponse {
        let chainId = chain.chainReference
        return try await client.get("swap/v6.0/\(chainId)/quote", q: [
            "fromTokenAddress": from,
            "toTokenAddress": to,
            "amount": amountWei,
            "includeTokens": "true"
        ]) as QuoteResponse
    }
}

func formatAmount(weiString: String, decimals: Int) -> String {
    let amount = Decimal(string: weiString) ?? 1
    var divisor = Decimal(1)
    for _ in 0..<decimals { divisor *= 10 }
    let value = amount / divisor
    return NSDecimalNumber(decimal: value).stringValue
}

