//
//  OneInchSwapResponse.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 27/07/2025.
//

struct OneInchSwapResponse: Decodable {
    let toAmount: String
    let tx: OneInchSwapTx
}
