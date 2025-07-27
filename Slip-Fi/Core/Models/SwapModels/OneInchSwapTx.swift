//
//  OneInchSwapTx.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 27/07/2025.
//

struct OneInchSwapTx: Decodable {
    let from: String?
    let to: String
    let data: String
    let value: String
    let gas: Int?
    let gasPrice: String?
    let maxFeePerGas: String?
    let maxPriorityFeePerGas: String?
}

