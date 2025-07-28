//
//  OneInchSwapService.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 27/07/2025.
//

import Foundation

protocol SwapService {
    func buildSwapTx_MaticToUSDC(amountWei: String, fromAddress: String) async throws -> OneInchSwapResponse
    func buildSwapTx_USDCtoWETH(amountWei: String, fromAddress: String) async throws -> OneInchSwapResponse
}

final class OneInchSwapService: SwapService {
    private let client = OneInchHTTPClient()

    func buildSwapTx_MaticToUSDC(amountWei: String, fromAddress: String) async throws -> OneInchSwapResponse {
        // chainId: 137 (Polygon)
        let path = "swap/v6.0/137/swap"
        let params: [String:String] = [
            "fromTokenAddress": Tokens.nativeMatic,
            "toTokenAddress": Tokens.usdcNative,
            "amount": amountWei, // wei
            "fromAddress": fromAddress, // user address
            "slippage": "1" // 1% as def
        ]
        let resp: OneInchSwapResponse = try await client.get(path, q: params)
        return resp
    }
    
    func buildSwapTx_USDCtoWETH(amountWei: String, fromAddress: String) async throws -> OneInchSwapResponse {
        let path = "swap/v6.0/137/swap"
        let params: [String: String] = [
            "fromTokenAddress": Tokens.usdcNative,
            "toTokenAddress": Tokens.weth,
            "amount": amountWei,
            "fromAddress": fromAddress,
            "slippage": "1"
        ]
        let resp: OneInchSwapResponse = try await client.get(path, q: params)
        return resp
    }

}
