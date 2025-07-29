//
//  SplitResult.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 29/07/2025.
//
import Foundation

struct SplitResult: Identifiable {
    var id: Int { parts }
    let parts: Int
    let totalToTokenAmount: Decimal
    var deltaVsOnePart: Decimal
}
