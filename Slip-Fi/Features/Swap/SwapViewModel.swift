//
//  SwapViewModel.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//
import SwiftUI
import ReownAppKit

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
                quote = try await quoteService.quote(from: Tokens.usdcNative, to: Tokens.weth, amountWei: inputWei, chain: MyChainPresets.polygon)
            } catch { self.error = error.localizedDescription }
            isLoading = false
        }
    }

    // D2 (swap without approve)
    func swapMaticToUsdc(amountMatic: Decimal) {
        Task { [self] in
            guard let fromAddress = AppKit.instance.getAddress() else {
                error = "Wallet not connected"
                return
            }
            do {
                isBuilding = true
                let wei = toWei(amountMatic, decimals: 18)
                let swapTx = try await swapService.buildSwapTx_MaticToUSDC(amountWei: wei, fromAddress: fromAddress)
                isBuilding = false
                isSending = true
                
                guard let tx = swapTx.tx else {
                    self.error = "1inch did not return a transaction. Try increasing the amount."
                    return
                }
                let hash = try await TxSender.shared.send(tx: tx, userAddress: fromAddress)
                txHash = hash
            } catch { self.error = error.localizedDescription }
            isSending = false
        }
    }

    // D3 (approve → swap USDC→WETH)
    func executeSwapUSDCtoWETH(amount: Decimal) {
        Task {
            guard !isLoading else { return }
            isLoading = true
            defer { isLoading = false }

            guard let wallet = AppKit.instance.getAddress() else {
                self.error = "Wallet not connected"
                return
            }

            let amountWei = toWei(amount, decimals: 6)
            lastAmountWei = amountWei

            do {
                let required = Decimal(string: amountWei) ?? 0
                var allowance = try await approveService.getAllowance(tokenAddress: Tokens.usdcNative, walletAddress: wallet)
                var allowanceValue = Decimal(string: allowance) ?? 0

                if allowanceValue < required {
                    let approveTx = try await approveService.buildApproveTx(tokenAddress: Tokens.usdcNative, amountWei: amountWei, walletAddress: wallet)
                    let hash = try await TxSender.shared.send(tx: approveTx.asOneInchSwapTx(), userAddress: wallet)

                    try await waitForTransactionConfirmation(txHash: hash)

                    allowance = try await approveService.getAllowance(tokenAddress: Tokens.usdcNative, walletAddress: wallet)
                    allowanceValue = Decimal(string: allowance) ?? 0

                    if allowanceValue < required {
                        self.error = "Allowance not updated after approval"
                        return
                    }
                }

                let swapTx = try await swapService.buildSwapTx_USDCtoWETH(amountWei: amountWei, fromAddress: wallet)
                guard let tx = swapTx.tx else {
                    self.error = "1inch did not return a transaction. Try increasing the amount."
                    return
                }
                let swapHash = try await TxSender.shared.send(tx: tx, userAddress: wallet)
                self.txHash = swapHash

            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - HELPERS

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
}

// MARK: - EXTENSIONS

extension OneInchApproveTx {
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

// MARK: - CONFIRMATION

func waitForTransactionConfirmation(txHash: String, interval: TimeInterval = 4.0, maxAttempts: Int = 30) async throws {
    let urlPrefix = "https://api.polygonscan.com/api"
    let apiKey = Secrets.polygonscanKey

    for _ in 0..<maxAttempts {
        guard let url = URL(string: "\(urlPrefix)?module=transaction&action=gettxreceiptstatus&txhash=\(txHash)&apikey=\(apiKey)") else {
            throw NSError(domain: "wait", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Polygonscan URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let status = (json?["result"] as? [String: String])?["status"]

        if status == "1" { return }

        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }

    throw NSError(domain: "wait", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout while waiting for tx confirmation"])
}
extension Secrets {
    static let polygonscanKey = value(for: "PolygonscanAPIKey")
}

enum Tokens {
    static let usdcNative = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    static let weth = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619"
    static let nativeMatic = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
}
