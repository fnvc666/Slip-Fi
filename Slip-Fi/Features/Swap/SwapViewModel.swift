//
//  SwapViewModel.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//
import Foundation
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
    @Published var splitResults: [SplitResult] = []
    @Published var bestSplit: SplitResult? = nil
    @Published var selectedParts: Int = 1  // as default N
    @Published var forceSplitEvenIfLoss: Bool = false
    @Published var isSplitRunning = false
    @Published var splitCurrent = 0
    @Published var splitTotal = 0
    @Published var splitProgressText: String?
    @Published var splitHashes: [String] = []
    @Published var splitCancel = false
    
    
    private let splitService: SplitSwapServiceProtocol
    private let quoteService: QuoteService = OneInchQuoteService()
    private let swapService: SwapService = OneInchSwapService()
    private let approveService: ApproveServiceProtocol = ApproveService()
    
    init(splitService: SplitSwapServiceProtocol) {
        self.splitService = splitService
    }
    
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
    
    // D4
    func startSplitSwapUSDCtoWETH(totalAmount: Decimal, parts: Int, slippageBps: Int) {
        guard parts >= 1, totalAmount > 0 else { return }
        guard let wallet = AppKit.instance.getAddress() else { return }
        
        isSplitRunning = true
        splitCancel = false
        splitCurrent = 0
        splitTotal = parts
        splitHashes = []
        splitProgressText = "Preparing…"
        
        Task {
            do {
                let hashes = try await splitService.executeSplitSwapUSDCtoWETH(
                    totalAmount: totalAmount,
                    parts: parts,
                    walletAddress: wallet,
                    slippageBps: currentSlippageBps(),
                    waitForConfirmation: false,
                    delayBetweenPartsMs: 0,
                    progress: { done, total in
                        self.splitCurrent = done
                        self.splitTotal = total
                        self.splitProgressText = "Part \(done)/\(total)…"
                    },
                    shouldCancel: { [weak self] in self?.splitCancel == true }
                )
                await MainActor.run {
                    self.splitHashes = hashes
                    self.splitProgressText = "Ready: \(hashes.count)/\(parts)"
                    //    self.appendSplitToHistory(totalAmount: totalAmount, parts: hashes.count, hashes: hashes)
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? CancellationError) != nil
                    ? "Stopped by user"
                    : error.localizedDescription
                    self.splitProgressText = "Error"
                }
            }
            await MainActor.run { self.isSplitRunning = false }
        }
    }
    
    func simulateSplitQuotes(from fromToken: String, to toToken: String,
                             amount: Decimal, maxParts: Int) {
        Task { [weak self] in
            guard let self, amount > 0, maxParts >= 1 else { return }
            self.isLoading = true
            defer { self.isLoading = false }
            do {
                let fromDecimals = 6
                let toDecimals = 18

                let totalWeiStr = toBaseUnitsString(amount, decimals: fromDecimals)
                var results: [SplitResult] = []

                for n in 1...maxParts {
                    let partWeiList = splitWei(totalWeiStr, parts: n)
                    var sumOutWei: Decimal = 0
                    for partWei in partWeiList {
                        let q = try await self.quoteService.quote(
                            from: fromToken, to: toToken,
                            amountWei: partWei, chain: MyChainPresets.polygon
                        )
                        if let dst = Decimal(string: q.dstAmount) { sumOutWei += dst }
                    }
                    let totalOut = sumOutWei / pow10(toDecimals)
                    results.append(.init(parts: n, totalToTokenAmount: totalOut, deltaVsOnePart: 0))
                }

                if let base = results.first?.totalToTokenAmount {
                    for i in results.indices {
                        results[i].deltaVsOnePart = results[i].totalToTokenAmount - base
                    }
                }

                let best = results.max(by: { $0.totalToTokenAmount < $1.totalToTokenAmount })
                await MainActor.run {
                    self.splitResults = results
                    self.bestSplit = best
                    self.selectedParts = best?.parts ?? 1
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
    
    func cancelSplit() { splitCancel = true }
    
    private func currentSlippageBps() -> Int { 100 }
    
    
    // D4 slip-algorithm
    //    func simulateSplitQuotes(from fromToken: String, to toToken: String, amount: Decimal, maxParts: Int) {
    //        Task { [weak self] in
    //            guard let self else { return }
    //            guard amount > 0, maxParts >= 1 else { return }
    //
    //            self.isLoading = true
    //            defer { self.isLoading = false }
    //
    //            do {
    //                let fromDecimals = 6
    //                let toDecimals = 18
    //
    //                let totalWeiStr = toBaseUnitsString(amount, decimals: fromDecimals)
    //                var results: [SplitResult] = []
    //
    //                for n in 1...maxParts {
    //                    let partWeiList = splitWei(totalWeiStr, parts: n)
    //                    var sumOutWei: Decimal = 0
    //
    //                    for partWei in partWeiList {
    //                        let q = try await self.quoteService.quote(
    //                            from: fromToken,
    //                            to: toToken,
    //                            amountWei: partWei,
    //                            chain: MyChainPresets.polygon
    //                        )
    //                        if let dst = Decimal(string: q.dstAmount) {
    //                            sumOutWei += dst
    //                        }
    //                    }
    //
    //                    let totalOut = sumOutWei / pow10(toDecimals)
    //                    results.append(.init(parts: n,
    //                                         totalToTokenAmount: totalOut,
    //                                         deltaVsOnePart: 0))
    //                }
    //
    //                if let base = results.first?.totalToTokenAmount {
    //                    for i in results.indices {
    //                        results[i].deltaVsOnePart = results[i].totalToTokenAmount - base
    //                    }
    //                }
    //
    //                let best = results.max(by: { $0.totalToTokenAmount < $1.totalToTokenAmount })
    //                await MainActor.run {
    //                    self.splitResults = results
    //                    self.bestSplit = best
    //                    self.selectedParts = best?.parts ?? 1
    //                }
    //
    //            } catch {
    //                await MainActor.run { self.error = error.localizedDescription }
    //            }
    //        }
    //    }
    
    //    func pow10(_ n: Int) -> Decimal {
    //        var r = Decimal(1)
    //        for _ in 0..<n { r *= 10 }
    //        return r
    //    }
    
    //    func toBaseUnitsString(_ amount: Decimal, decimals: Int) -> String {
    //        let scaled = NSDecimalNumber(decimal: amount * pow10(decimals))
    //        let handler = NSDecimalNumberHandler(
    //            roundingMode: .down, scale: 0,
    //            raiseOnExactness: false, raiseOnOverflow: false,
    //            raiseOnUnderflow: false, raiseOnDivideByZero: false
    //        )
    //        return scaled.rounding(accordingToBehavior: handler).stringValue
    //    }
    //
    //    func splitWei(_ totalWeiStr: String, parts: Int) -> [String] {
    //        guard let total = UInt64(totalWeiStr), parts > 0 else { return [] }
    //        let base = total / UInt64(parts)
    //        let rem  = total % UInt64(parts)
    //        var out: [String] = []
    //        out.reserveCapacity(parts)
    //        for i in 0..<parts {
    //            let add = i < rem ? 1 : 0
    //            out.append(String(base + UInt64(add)))
    //        }
    //        return out
    //    }
    
}

// MARK: - HELPERS

func toWei(_ amount: Decimal, decimals: Int) -> String {
    var v = amount
    for _ in 0..<decimals { v *= 10 }
    return NSDecimalNumber(decimal: v).stringValue
}

func toBaseUnitsString(_ amount: Decimal, decimals: Int) -> String {
    let scaled = NSDecimalNumber(decimal: amount * pow10(decimals))
    let h = NSDecimalNumberHandler(roundingMode: .down, scale: 0,
                                   raiseOnExactness: false, raiseOnOverflow: false,
                                   raiseOnUnderflow: false, raiseOnDivideByZero: false)
    return scaled.rounding(accordingToBehavior: h).stringValue
}

func splitWei(_ totalWeiStr: String, parts: Int) -> [String] {
    guard let total = UInt64(totalWeiStr), parts > 0 else { return [] }
    let base = total / UInt64(parts)
    let rem  = total % UInt64(parts)
    return (0..<parts).map { String(base + (UInt64($0) < rem ? 1 : 0)) }
}

func pow10(_ n: Int) -> Decimal {
        var r = Decimal(1)
        for _ in 0..<n { r *= 10 }
        return r
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

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
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
    
    static let wethDecimals = 18
}
