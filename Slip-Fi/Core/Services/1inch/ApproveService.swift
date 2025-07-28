//
//  ApproveService.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 27/07/2025.
//

import Foundation

protocol ApproveServiceProtocol {
    func getAllowance(tokenAddress: String, walletAddress: String) async throws -> String
    func buildApproveTx(tokenAddress: String, amountWei: String, walletAddress: String) async throws -> OneInchApproveTx
}

final class ApproveService: ApproveServiceProtocol {
    private let client = OneInchHTTPClient()
    private let chainId = "137"

    func getAllowance(tokenAddress: String, walletAddress: String) async throws -> String {
        let path = "/swap/v6.0/\(chainId)/approve/allowance"
        let params = [
            "tokenAddress": tokenAddress,
            "walletAddress": walletAddress
        ]
        let resp: OneInchAllowanceResponse = try await client.get(path, q: params)
        return resp.allowance
    }

    func buildApproveTx(tokenAddress: String, amountWei: String, walletAddress: String) async throws -> OneInchApproveTx {
        let path = "/swap/v6.0/\(chainId)/approve/transaction"
        let params = [
            "tokenAddress": tokenAddress,
            "amount": amountWei,
            "walletAddress": walletAddress
        ]
        return try await client.get(path, q: params)
    }

}
