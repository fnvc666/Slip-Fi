//
//  SwapViewModel.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//
import Foundation
import SwiftUI
import ReownAppKit
import Combine

struct SplitState {
    var results: [SplitResult] = []
    var best: SplitResult? = nil
    var selectedParts: Int = 1
    var isRunning = false
    var current = 0
    var total = 0
    var progressText: String? = nil
    var hashes: [String] = []
}


@MainActor
final class SwapViewModel: ObservableObject {
    
    @Published var payText: String = ""
    @Published var receiveText: String = ""
    
    @Published var isQuoteLoadingPay = false
    @Published var isQuoteLoadingReceive = false
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var quote: QuoteResponse?
    @Published var lastAmountWei: String = ""
    @Published var txHash: String?
    @Published var isBuilding = false
    @Published var isSending = false
    @Published var splitCancel = false
    
    @Published var isQuoteLoading = false
    @Published var usdcBalance: Decimal = 0
    @Published var wethBalance: Decimal = 0
    @Published var isUsdcToWeth = true
    @Published var wethBalanceUSD: Decimal = 0
    
    @Published var successBanner: String? = nil
    
    @Published var split = SplitState()
    
    private var cancellables = Set<AnyCancellable>()
    private var isProgrammaticUpdate = false
    private var quoteRefreshTask: Task<Void, Never>? = nil
    private let historyKey = "swapHistory"
    
    private let history = HistoryStore.shared
    
    private var ignoreNextPayChange = false
    private var ignoreNextReceiveChange = false
    
    
    private let splitService: SplitSwapServiceProtocol
    private let quoteService: QuoteService = OneInchQuoteService()
    private let swapService: SwapService = OneInchSwapService()
    private let approveService: ApproveServiceProtocol = ApproveService()
    
    init(splitService: SplitSwapServiceProtocol) {
        self.splitService = splitService
        
//        quoteCancellable = $payText
//            .debounce(for: .seconds(2), scheduler: RunLoop.main)
//            .sink { [weak self] txt in
//                guard let self, let d = Decimal(string: txt), d > 0 else { return }
//                self.requestQuote(amount: d)
//            }
        
        $payText
            .removeDuplicates()
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] txt in
                guard let self else { return }
                // если поле изменили программно — заглушаем РОВНО один раз
                if self.ignoreNextPayChange {
                    self.ignoreNextPayChange = false
                    return
                }
                guard let d = Decimal(string: txt), d > 0 else {
                    self.ignoreNextReceiveChange = true  // чтобы очистка receive не триггерила обратный пересчёт
                    self.receiveText = ""
                    self.quote = nil
                    return
                }
                // Прямой расчёт: USDC -> WETH
                self.requestQuoteForward(usdcAmount: d)
            }
            .store(in: &cancellables)
        
        $receiveText
            .removeDuplicates()
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] txt in
                guard let self else { return }
                if self.ignoreNextReceiveChange {
                    self.ignoreNextReceiveChange = false
                    return
                }
                guard let d = Decimal(string: txt), d > 0 else {
                    self.ignoreNextPayChange = true      // чтобы очистка pay не триггерила пересчёт
                    self.payText = ""
                    self.quote = nil
                    return
                }
                // Обратный расчёт: хотим X WETH -> считаем, сколько нужно USDC
                self.requestQuoteReverse(wethAmount: d)
            }
            .store(in: &cancellables)
        
        
        
        updateBalances()
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
    
    // D4
//    func startSplitSwapUSDCtoWETH(totalAmount: Decimal, parts: Int, slippageBps: Int) {
//        guard parts >= 1, totalAmount > 0 else { return }
//        guard let wallet = AppKit.instance.getAddress() else { return }
//        
//        split.isRunning = true
//        splitCancel = false
//        split.current = 0
//        split.total = parts
//        split.hashes = []
//        split.progressText = "Preparing…"
//        
//        stopQuoteAutoRefresh()
//        Task {
//            do {
//                let hashes = try await splitService.executeSplitSwapUSDCtoWETH(
//                    totalAmount: totalAmount,
//                    parts: parts,
//                    walletAddress: wallet,
//                    slippageBps: currentSlippageBps(),
//                    waitForConfirmation: false,
//                    delayBetweenPartsMs: 250,
//                    progress: { done, total in
//                        self.split.current = done
//                        self.split.total = total
//                        self.split.progressText = "Part \(done)/\(total)…"
//                    },
//                    shouldCancel: { [weak self] in self?.splitCancel == true }
//                )
//                await MainActor.run {
//                    self.split.hashes = hashes
//                    self.successBanner = "✅ Отправлено \(hashes.count) транзакций split-swap. Баланс обновится после подтверждений."
//                    self.appendToHistory(txHashes: hashes)
//                }
//                if let last = hashes.last {
//                    Task.detached { [weak self] in
//                        do {
//                            try await waitForTransactionConfirmation(txHash: last)
//                            await MainActor.run { self?.updateBalances() }
//                        } catch { }
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    self.error = (error as? CancellationError) != nil
//                    ? "Stopped by user"
//                    : error.localizedDescription
//                    self.split.progressText = "Error"
//                }
//            }
//            await MainActor.run { self.split.isRunning = false }
//        }
//    }
    
    func simulateSplitQuotes(from fromToken: String, to toToken: String,
                             amount: Decimal, maxParts: Int) {
        Task { [weak self] in
            guard let self, amount > 0, maxParts >= 1 else { return }
            self.isLoading = true
            defer { self.isLoading = false }
            do {
                let fromDecimals = (fromToken == Tokens.usdcNative) ? 6 : Tokens.wethDecimals
                let toDecimals   = (toToken   == Tokens.usdcNative) ? 6 : Tokens.wethDecimals

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
                    self.split.results = results
                    self.split.best = best
                    self.split.selectedParts = best?.parts ?? 1
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }

    
    func cancelSplit() { splitCancel = true }
    
    private func currentSlippageBps() -> Int { 100 }
    
    // D5-6
    
    func updateBalances() {
        Task {
            guard let addr = AppKit.instance.getAddress() else { return }
            do {
                let usdcWei = try await ERC20BalanceService.balanceOfWei(
                    token: Tokens.usdcNative, wallet: addr, rpcUrl: MyChainPresets.polygon.rpcUrl)
                let wethWei = try await ERC20BalanceService.balanceOfWei(
                    token: Tokens.weth, wallet: addr, rpcUrl: MyChainPresets.polygon.rpcUrl)
                await MainActor.run {
                    self.usdcBalance = usdcWei / pow10(6)
                    self.wethBalance = wethWei / pow10(18)
                }
                let oneWethWei = toWei(1, decimals: Tokens.wethDecimals)
                let quote = try await quoteService.quote(
                    from: Tokens.weth, to: Tokens.usdcNative,
                    amountWei: oneWethWei, chain: MyChainPresets.polygon)
                if let usdcOutWei = Decimal(string: quote.dstAmount) {
                    let priceOneWeth = usdcOutWei / pow10(6)
                    let wethAmount = wethWei / pow10(18)
                    await MainActor.run {
                        self.wethBalanceUSD = wethAmount * priceOneWeth
                    }
                }
            } catch {
                print("Ошибка обновления балансов:", error)
            }
        }
    }
    
    private func requestQuoteForward(usdcAmount: Decimal) {
        stopQuoteAutoRefresh()
        Task { [self] in
            isQuoteLoadingReceive = true
            defer { isQuoteLoadingReceive = false }
            do {
                let wei = toWei(usdcAmount, decimals: 6)
                let q = try await quoteService.quote(
                    from: Tokens.usdcNative, to: Tokens.weth,
                    amountWei: wei, chain: MyChainPresets.polygon
                )
                let outWei = Decimal(string: q.dstAmount) ?? 0
                let out = outWei / pow10(Tokens.wethDecimals)
                
                await MainActor.run {
                    self.quote = q
                    self.ignoreNextReceiveChange = true     // <— ВАЖНО
                    self.receiveText = NSDecimalNumber(decimal: out).stringValue
                }
                startQuoteAutoRefresh()
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
    
    
    
    private func requestQuoteReverse(wethAmount: Decimal) {
        stopQuoteAutoRefresh()
        Task { [self] in
            isQuoteLoadingPay = true
            defer { isQuoteLoadingPay = false }
            do {
                let wei = toWei(wethAmount, decimals: Tokens.wethDecimals)
                let q = try await quoteService.quote(
                    from: Tokens.weth, to: Tokens.usdcNative,
                    amountWei: wei, chain: MyChainPresets.polygon
                )
                let usdcWei = Decimal(string: q.dstAmount) ?? 0
                let usdc = usdcWei / pow10(6)
                
                await MainActor.run {
                    self.ignoreNextPayChange = true         // <— ВАЖНО
                    self.payText = NSDecimalNumber(decimal: usdc).stringValue
                }
                // чтобы обновить и receive по прямому пути
                self.requestQuoteForward(usdcAmount: usdc)
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
    
    
    
    private func startQuoteAutoRefresh() {
        stopQuoteAutoRefresh()
        
        quoteRefreshTask = Task.detached { [weak self] in
            guard let self else { return }
            
            while !Task.isCancelled {
                // ... внутри while
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)     // 5с показываем цифру
                if Task.isCancelled { break }

                let (payAmount, isForward) = await MainActor.run {
                    (Decimal(string: self.payText) ?? 0, self.isUsdcToWeth)
                }

                // Включаем прогресс на ровно 2 секунды
                await MainActor.run { self.isQuoteLoadingReceive = true }

                let fetchTask = Task.detached { () -> (QuoteResponse?, Decimal?) in
                    do {
                        if isForward {
                            let wei = toWei(payAmount, decimals: 6)
                            let q = try await self.quoteService.quote(
                                from: Tokens.usdcNative, to: Tokens.weth,
                                amountWei: wei, chain: MyChainPresets.polygon
                            )
                            if let outWei = Decimal(string: q.dstAmount) {
                                return (q, outWei / pow10(Tokens.wethDecimals))
                            }
                        } else {
                            let wei = toWei(payAmount, decimals: Tokens.wethDecimals)
                            let q = try await self.quoteService.quote(
                                from: Tokens.weth, to: Tokens.usdcNative,
                                amountWei: wei, chain: MyChainPresets.polygon
                            )
                            if let outWei = Decimal(string: q.dstAmount) {
                                return (q, outWei / pow10(6))
                            }
                        }
                    } catch {}
                    return (nil, nil)
                }

                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                let (q, out) = await fetchTask.value
                if Task.isCancelled { break }

                await MainActor.run {
                    self.isQuoteLoadingReceive = false
                    if let q, let out {
                        self.quote = q
                        self.ignoreNextReceiveChange = true
                        self.receiveText = NSDecimalNumber(decimal: out).stringValue
                    }
                }

            }
        }
    }
    
    
    
    private func stopQuoteAutoRefresh() {
        quoteRefreshTask?.cancel()
        quoteRefreshTask = nil
    }
    
    
    
    func switchDirection() {
        stopQuoteAutoRefresh()
        isUsdcToWeth.toggle()
        quote = nil
        split.results.removeAll(); split.best = nil

        ignoreNextPayChange = true
        ignoreNextReceiveChange = true
        swap(&payText, &receiveText)

        if let d = Decimal(string: payText), d > 0 {
            if isUsdcToWeth {
                requestQuoteForward(usdcAmount: d)  // USDC -> WETH
            } else {
                requestQuoteReverse(wethAmount: d)  // WETH -> USDC
            }
        }
    }
    
    @MainActor
    private func saveHistory(txHashes: [String]) {
        let fromToken = isUsdcToWeth ? "USDC" : "WETH"
        let toToken   = isUsdcToWeth ? "WETH" : "USDC"
        let fromAmount = Decimal(string: self.payText) ?? 0
        let toAmount   = Decimal(string: self.receiveText) ?? 0

        let entry = TransactionModel(
            date: Date(),
            fromToken: fromToken,
            fromAmount: NSDecimalNumber(decimal: fromAmount).doubleValue,
            toToken: toToken,
            toAmount: NSDecimalNumber(decimal: toAmount).doubleValue,
            txArray: txHashes
        )
        history.append(entry)
        self.successBanner = "✅ Транзакция(и) отправлены. Баланс обновится после подтверждений."
    }


    func executeSwap() {
        guard let amount = Decimal(string: payText), amount > 0 else { return }
        if isUsdcToWeth {
            executeSwapUSDCtoWETH(amount: amount)
        } else {
            executeSwapWETHtoUSDC(amount: amount)
        }
    }

    // USDC -> WETH
    func executeSwapUSDCtoWETH(amount: Decimal) {
        stopQuoteAutoRefresh()
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
                var txHashes: [String] = []
                let required = Decimal(string: amountWei) ?? 0
                let allowance = try await approveService.getAllowance(tokenAddress: Tokens.usdcNative,
                                                                     walletAddress: wallet)
                let needsApprove = (Decimal(string: allowance) ?? 0) < required

                if needsApprove {
                    let approveTx = try await approveService.buildApproveTx(tokenAddress: Tokens.usdcNative,
                                                                            amountWei: amountWei,
                                                                            walletAddress: wallet)
                    _ = try await TxSender.shared.send(tx: approveTx.asOneInchSwapTx(), userAddress: wallet)
                    // пользователь подтвердил и вернулся в приложение
                }

                // готовим swap-запрос
                let swapTx = try await swapService.buildSwapTx_USDCtoWETH(amountWei: amountWei, fromAddress: wallet)
                guard let tx = swapTx.tx else {
                    self.error = "1inch did not return a transaction. Try increasing the amount."
                    return
                }

                // отправляем запрос на swap...
                let swapHashTask = Task { try await TxSender.shared.send(tx: tx, userAddress: wallet) }

                // ...и если только что был approve — ПОДНИМАЕМ кошелёк сами
                if needsApprove {
                    try await Task.sleep(nanoseconds: 300_000_000) // 0.3s чтобы UI успел вернуться
                    await MainActor.run {
                        print("вызван")
                        // В Reown AppKit:
                        AppKit.instance.launchCurrentWallet()        // или Router.openWallet() в старых версиях
                        // Если своего метода нет — открой диплинк конкретного кошелька, напр.:
                        // UIApplication.shared.open(URL(string: "metamask://")!)
                    }
                } else {
                    print("не вызван")
                }

                let swapHash = try await swapHashTask.value
                txHashes.append(swapHash)
                await MainActor.run {
                    self.split.hashes = txHashes
                    self.saveHistory(txHashes: txHashes)
                }

                try await waitForTransactionConfirmation(txHash: swapHash)
                await MainActor.run { self.updateBalances() }

            } catch { self.error = error.localizedDescription }
        }
    }


    // WETH -> USDC
    func executeSwapWETHtoUSDC(amount: Decimal) {
        stopQuoteAutoRefresh()
        Task {
            guard !isLoading else { return }
            isLoading = true
            defer { isLoading = false }

            guard let wallet = AppKit.instance.getAddress() else {
                self.error = "Wallet not connected"
                return
            }

            let amountWei = toWei(amount, decimals: Tokens.wethDecimals)
            lastAmountWei = amountWei

            do {
                var txHashes: [String] = []

                let required = Decimal(string: amountWei) ?? 0
                let allowanceStr = try await approveService.getAllowance(tokenAddress: Tokens.weth,
                                                                         walletAddress: wallet)
                let allowance = Decimal(string: allowanceStr) ?? 0
                let needsApprove = allowance < required

                if needsApprove {
                    let approveTx = try await approveService.buildApproveTx(tokenAddress: Tokens.weth,
                                                                            amountWei: amountWei,
                                                                            walletAddress: wallet)
                    let approveHash = try await TxSender.shared.send(tx: approveTx.asOneInchSwapTx(),
                                                                     userAddress: wallet)
                    txHashes.append(approveHash)
                }

                let swapTx = try await swapService.buildSwapTx_WETHtoUSDC(amountWei: amountWei,
                                                                          fromAddress: wallet)
                guard let tx = swapTx.tx else {
                    self.error = "1inch did not return a transaction. Try increasing the amount."
                    return
                }

                // 🔑 как в USDC->WETH: запускаем отправку и поднимаем кошелёк
                let swapHashTask = Task { try await TxSender.shared.send(tx: tx, userAddress: wallet) }
                if needsApprove {
                    try await Task.sleep(nanoseconds: 300_000_000) // 0.3s, чтобы UI вернулся
                    await MainActor.run { AppKit.instance.launchCurrentWallet() }
                }

                let swapHash = try await swapHashTask.value
                txHashes.append(swapHash)

                await MainActor.run {
                    self.split.hashes = txHashes
                    self.saveHistory(txHashes: txHashes)
                }

                try await waitForTransactionConfirmation(txHash: swapHash)
                await MainActor.run { self.updateBalances() }

            } catch {
                self.error = error.localizedDescription
            }
        }
    }


    func startSplitSwap(totalAmount: Decimal, parts: Int, slippageBps: Int) {
        guard parts >= 1, totalAmount > 0 else { return }
        guard let wallet = AppKit.instance.getAddress() else { return }

        split.isRunning = true
        splitCancel = false
        split.current = 0
        split.total = parts
        split.hashes = []
        split.progressText = "Preparing…"

        stopQuoteAutoRefresh()

        Task {
            do {
                let (fromToken, fromDecimals, toToken, toDecimals) = isUsdcToWeth
                ? (Tokens.usdcNative, 6, Tokens.weth, Tokens.wethDecimals)
                : (Tokens.weth, Tokens.wethDecimals, Tokens.usdcNative, 6)

                // approve (на весь totalAmount) заранее — чтобы не делать approve на каждую часть
                do {
                    let totalWei = toWei(totalAmount, decimals: fromDecimals)
                    let required = Decimal(string: totalWei) ?? 0
                    let allowance = try await approveService.getAllowance(tokenAddress: fromToken, walletAddress: wallet)
                    let allowanceValue = Decimal(string: allowance) ?? 0
                    if allowanceValue < required {
                        let approveTx = try await approveService.buildApproveTx(tokenAddress: fromToken, amountWei: totalWei, walletAddress: wallet)
                        let approveHash = try await TxSender.shared.send(tx: approveTx.asOneInchSwapTx(), userAddress: wallet)
                        // логируем в список хэшей сразу, но не ждём
                        await MainActor.run {
                            self.split.hashes.append(approveHash)
                            self.successBanner = "✅ Approval отправлен. Начинаем split…"
                        }
                    }
                }

                // теперь отправляем сами части
                let hashes = try await splitService.executeSplitSwap(
                    fromToken: fromToken, fromDecimals: fromDecimals,
                    toToken: toToken, toDecimals: toDecimals,
                    totalAmount: totalAmount, parts: parts, walletAddress: wallet,
                    slippageBps: slippageBps, waitForConfirmation: false, delayBetweenPartsMs: 1000,
                    progress: { done, total in
                        self.split.current = done
                        self.split.total = total
                        self.split.progressText = "Part \(done)/\(total)…"
                    },
                    shouldCancel: { [weak self] in self?.splitCancel == true }
                )

                await MainActor.run {
                    self.split.hashes.append(contentsOf: hashes)
                    self.successBanner = "✅ Отправлено \(hashes.count) транзакций split-swap."
                    self.saveHistory(txHashes: self.split.hashes)
                }

                // ждём подтверждение последнего, потом обновляем баланс (асинхронно)
                if let last = hashes.last {
                    Task.detached { [weak self] in
                        do {
                            try await waitForTransactionConfirmation(txHash: last)
                            await MainActor.run { self?.updateBalances() }
                        } catch {}
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? CancellationError) != nil ? "Stopped by user" : error.localizedDescription
                    self.split.progressText = "Error"
                }
            }
            await MainActor.run { self.split.isRunning = false }
        }
    }

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
