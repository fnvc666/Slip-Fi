//
//  SwapViewModel.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//
import SwiftUI
import ReownAppKit

@MainActor
final class SwapViewModel: ObservableObject {
    // — существующие поля —
    @Published var isLoading = false
    @Published var error: String?
    @Published var quote: QuoteResponse?
    @Published var lastAmountWei: String = "0"

    // — добавим под D2 —
    @Published var isBuilding = false
    @Published var isSending  = false
    @Published var txHash: String?

    private let quoteSvc = OneInchQuoteService()
    private let swapSvc  = OneInchSwapService()

    // D1 (оставляем как было)
    func getQuoteUSDCtoWETH(amountUSDC: Decimal) {
        Task { [self] in
            do {
                isLoading = true
                let inputWei = toWei(amountUSDC, decimals: 6) // USDC(6)
                lastAmountWei = inputWei
                quote = try await quoteSvc.quote(from: Tokens.usdc, to: Tokens.weth, amountWei: inputWei, chain: MyChainPresets.polygon)
            } catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }

    // D2: MATIC → USDC (без approve)
    func swapMaticToUsdc(amountMatic: Decimal) {
        Task { [self] in
            guard let fromAddress = AppKit.instance.getAddress() else {
                error = "Wallet not connected"
                return
            }
            do {
                isBuilding = true
                let wei = toWei(amountMatic, decimals: 18) // MATIC(18)
                let tx = try await swapSvc.buildSwapTx_MaticToUSDC(amountWei: wei, fromAddress: fromAddress)
                isBuilding = false

                isSending = true
                let hash = try await TxSender.shared.send(tx: tx, userAddress: fromAddress)
                txHash = hash
            } catch { self.error = error.localizedDescription }
            isSending = false
        }
    }
}

// Хелпер
func toWei(_ amount: Decimal, decimals: Int) -> String {
    var v = amount
    for _ in 0..<decimals { v *= 10 }
    return NSDecimalNumber(decimal: v).stringValue
}

enum Tokens {
    static let usdc = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    static let weth = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619"
    static let nativeMatic = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
}

enum MyChainPresets {
    static let polygon = Chain(
        chainName: "Polygon",
        chainNamespace: "eip155",
        chainReference: "137",
        requiredMethods: [],
        optionalMethods: [],
        events: [],
        token: .init(name: "MATIC", symbol: "MATIC", decimal: 18),
        rpcUrl: "https://polygon-rpc.com",
        blockExplorerUrl: "https://polygonscan.com",
        imageId: "polygon"
    )
}
