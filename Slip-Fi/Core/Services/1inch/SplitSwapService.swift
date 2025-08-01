//
//  SplitSwapService.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 29/07/2025.
//
import Foundation

protocol SplitSwapServiceProtocol {
    func executeSplitSwapUSDCtoWETH(
        totalAmount: Decimal,
        parts: Int,
        walletAddress: String,
        slippageBps: Int,
        waitForConfirmation: Bool,
        delayBetweenPartsMs: Int,
        progress: @escaping (Int, Int) -> Void,   // (currentPartIndex, totalParts)
        shouldCancel: @escaping () -> Bool       // callback
    ) async throws -> [String]
}

final class SplitSwapService: SplitSwapServiceProtocol {
    private let quoteService: QuoteService
    private let swapService: SwapService
    private let approveService: ApproveService
    private let txSender: TxSender

    init(quoteService: QuoteService,
         swapService: SwapService,
         approveService: ApproveService,
         txSender: TxSender = .shared) {
        self.quoteService = quoteService
        self.swapService = swapService
        self.approveService = approveService
        self.txSender = txSender
    }

    private let USDC_DECIMALS = 6
    private let DELAY_NS: UInt64 = 2_000_000_000 // ~2s

    public func executeSplitSwapUSDCtoWETH(
        totalAmount: Decimal,
        parts: Int,
        walletAddress: String,
        slippageBps: Int,
        waitForConfirmation: Bool,
        delayBetweenPartsMs: Int,
        progress: @escaping (Int, Int) -> Void,
        shouldCancel: @escaping () -> Bool
    ) async throws -> [String] {

        precondition(parts >= 1 && totalAmount > 0)

        let totalWei = toBaseUnitsString(totalAmount, decimals: USDC_DECIMALS)
        try await ensureApproveIfNeeded(totalWei: totalWei, wallet: walletAddress)

        let chunks = splitWei(totalWei, parts: parts)
        var hashes: [String] = []
        hashes.reserveCapacity(parts)

        for (idx, partWei) in chunks.enumerated() {
            if shouldCancel() { break }

            _ = try? await quoteService.quote(
                from: Tokens.usdcNative,
                to:   Tokens.weth,
                amountWei: partWei,
                chain: MyChainPresets.polygon
            )

            // build swap tx for slippage
            let swapResp = try await swapService.buildSwapTx_USDCtoWETH(
                amountWei: partWei,
                fromAddress: walletAddress
            )
            guard let swapTx = swapResp.tx else {
                throw NSError(domain: "swap", code: -1, userInfo: [NSLocalizedDescriptionKey: "1inch doesn't return tx"])
            }
            let hash = try await txSender.send(tx: swapTx, userAddress: walletAddress)
            hashes.append(hash)

            if waitForConfirmation {
                try? await txSender.waitForTransactionConfirmation(txHash: hash)
            }

            await MainActor.run { progress(idx + 1, parts) }

            if delayBetweenPartsMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayBetweenPartsMs) * 1_000_000)
            }
        }
        return hashes
    }

    private func ensureApproveIfNeeded(totalWei: String, wallet: String) async throws {
        // 1) текущий allowance
        let allowanceStr = try await approveService.getAllowance(
            tokenAddress: Tokens.usdcNative,
            walletAddress: wallet
        )
        let allowance = Decimal(string: allowanceStr) ?? 0
        let need      = Decimal(string: totalWei) ?? 0

        guard allowance < need else { return }

        let maxUint256 = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        let approveTx = try await approveService.buildApproveTx(
            tokenAddress: Tokens.usdcNative,
            amountWei: maxUint256,
            walletAddress: wallet
        )
        let hash = try await txSender.send(approveTx: approveTx, userAddress: wallet)
        try await txSender.waitForTransactionConfirmation(txHash: hash)
    }


    // MARK: - Helpers
    
    func toBaseUnitsString(_ amount: Decimal, decimals: Int) -> String {
        let scaled = NSDecimalNumber(decimal: amount * pow10(decimals))
        let handler = NSDecimalNumberHandler(
            roundingMode: .down, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        return scaled.rounding(accordingToBehavior: handler).stringValue
    }

    func splitWei(_ totalWeiStr: String, parts: Int) -> [String] {
        guard let total = UInt64(totalWeiStr), parts > 0 else { return [] }
        let base = total / UInt64(parts)
        let rem  = total % UInt64(parts)
        var out: [String] = []
        out.reserveCapacity(parts)
        for i in 0..<parts {
            let add = i < rem ? 1 : 0
            out.append(String(base + UInt64(add)))
        }
        return out
    }
    
    func pow10(_ n: Int) -> Decimal {
        var r = Decimal(1)
        for _ in 0..<n { r *= 10 }
        return r
    }
}
