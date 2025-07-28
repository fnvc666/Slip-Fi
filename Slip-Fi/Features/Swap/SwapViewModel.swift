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
    @Published var lastAmountWei: String = ""
    @Published var txHash: String?
    @Published var isBuilding = false
    @Published var isSending = false

    private let quoteService: QuoteService = OneInchQuoteService()
    private let swapService: SwapService = OneInchSwapService()
    private let approveService: ApproveServiceProtocol = ApproveService()

    // D1 (quote)
    func getQuoteUSDCtoWETH(amountUSDC: Decimal) {
        Task { [self] in
            do {
                isLoading = true
                let inputWei = toWei(amountUSDC, decimals: 6)
                lastAmountWei = inputWei
                quote = try await quoteService.quote(from: Tokens.usdc, to: Tokens.weth, amountWei: inputWei, chain: MyChainPresets.polygon)
            } catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }

    // D2 (swap без approve)
    func swapMaticToUsdc(amountMatic: Decimal) {
        Task { [self] in
            guard let fromAddress = AppKit.instance.getAddress() else {
                error = "Wallet not connected"
                return
            }
            do {
                isBuilding = true
                let wei = toWei(amountMatic, decimals: 18)
                let tx = try await swapService.buildSwapTx_MaticToUSDC(amountWei: wei, fromAddress: fromAddress)
                isBuilding = false

                isSending = true
                let hash = try await TxSender.shared.send(tx: tx, userAddress: fromAddress)
                txHash = hash
            } catch { self.error = error.localizedDescription }
            isSending = false
        }
    }

    // D3 (approve → swap USDC→WETH)
    func executeSwapUSDCtoWETH(amount: Decimal) {
        Task {
            isLoading = true
            defer { isLoading = false }

            guard let wallet = AppKit.instance.getAddress() else {
                self.error = "Wallet not connected"
                return
            }

            let amountWei = toWei(amount, decimals: 6)
            lastAmountWei = amountWei

            do {
                let allowance = try await approveService.getAllowance(tokenAddress: Tokens.usdc, walletAddress: wallet)
                let allowanceValue = Decimal(string: allowance) ?? 0
                let required = Decimal(string: amountWei) ?? 0

                if allowanceValue < required {
                    let approveTx = try await approveService.buildApproveTx(tokenAddress: Tokens.usdc, amountWei: amountWei, walletAddress: wallet)
                    _ = try await TxSender.shared.send(tx: approveTx.asOneInchSwapTx(), userAddress: wallet)
                }

                let swapTx = try await swapService.buildSwapTx_MaticToUSDC(amountWei: amountWei, fromAddress: wallet)
                let hash = try await TxSender.shared.send(tx: swapTx, userAddress: wallet)
                self.txHash = hash

            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

private extension OneInchApproveTx {
    func asOneInchSwapTx() -> OneInchSwapTx {
        .init(
            from: self.from,
            to: self.to,
            data: self.data,
            value: self.value,
            gas: self.gas,
            gasPrice: self.gasPrice,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }
}

// Токены
enum Tokens {
    static let usdc = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    static let weth = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619"
    static let nativeMatic = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
}

// Хелпер
func toWei(_ amount: Decimal, decimals: Int) -> String {
    var v = amount
    for _ in 0..<decimals { v *= 10 }
    return NSDecimalNumber(decimal: v).stringValue
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
