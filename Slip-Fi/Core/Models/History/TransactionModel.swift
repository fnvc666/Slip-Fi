//
//  History.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 02/08/2025.
//

import Foundation

struct TransactionModel: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var fromToken: String
    var fromAmount: Double
    var toToken: String
    var toAmount: Double
    var txArray: [String]
}
