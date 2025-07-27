//
//  OneInchSwapService.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 27/07/2025.
//

import Foundation

protocol SwapService {
    func buildSwapTx_MaticToUSDC(amountWei: String, fromAddress: String) async throws -> OneInchSwapTx
}

final class OneInchSwapService: SwapService {
    private let client = OneInchHTTPClient()

    func buildSwapTx_MaticToUSDC(amountWei: String, fromAddress: String) async throws -> OneInchSwapTx {
        // chainId: 137 (Polygon)
        let path = "swap/v5.2/137/swap"
        let params: [String:String] = [
            "fromTokenAddress": Tokens.nativeMatic,
            "toTokenAddress": Tokens.usdc,
            "amount": amountWei, // wei
            "fromAddress": fromAddress, // user address
            "slippage": "1" // 1% as def
        ]
        let resp: OneInchSwapResponse = try await client.get(path, q: params)
        return resp.tx
    }
}
