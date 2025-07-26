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
    @Published var isLoading = false
    @Published var error: String?
    @Published var quote: QuoteResponse?
    @Published var lastAmountWei: String = "0"

    private let svc: QuoteService = OneInchQuoteService()

    func getQuoteUSDCtoWETH(amountUSDC: Decimal) {
        Task { [self] in
            do {
                self.isLoading = true
                // 1 USDC = 6 decimals
                let inputAmountWei = (amountUSDC * pow(10, 6) as NSDecimalNumber).stringValue
                self.lastAmountWei = inputAmountWei
                quote = try await self.svc.quote(from: Tokens.usdc, to: Tokens.weth, amountWei: inputAmountWei, chain: MyChainPresets.polygon)
            } catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }
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
