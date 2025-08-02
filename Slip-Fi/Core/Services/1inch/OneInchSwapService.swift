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
    func buildSwapTx_WETHtoUSDC(amountWei: String, fromAddress: String) async throws -> OneInchSwapResponse
}


final class OneInchSwapService: SwapService {
    private let client = OneInchHTTPClient()

    func buildSwapTx_MaticToUSDC(amountWei: String, fromAddress: String) async throws -> OneInchSwapResponse {
        let path = "swap/v6.0/137/swap"
        let params: [String:String] = [
            "fromTokenAddress": Tokens.nativeMatic,
            "toTokenAddress": Tokens.usdcNative,
            "amount": amountWei,
            "fromAddress": fromAddress,
            "slippage": "1"
        ]
        return try await client.get(path, q: params)
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
        return try await client.get(path, q: params)
    }

    func buildSwapTx_WETHtoUSDC(amountWei: String, fromAddress: String) async throws -> OneInchSwapResponse {
        let path = "swap/v6.0/137/swap"
        let params: [String: String] = [
            "fromTokenAddress": Tokens.weth,
            "toTokenAddress": Tokens.usdcNative,
            "amount": amountWei,
            "fromAddress": fromAddress,
            "slippage": "1"
        ]
        return try await client.get(path, q: params)
    }
}

