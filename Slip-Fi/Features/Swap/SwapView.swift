//
//  SwapView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//
import SwiftUI

struct SwapView: View {
    @StateObject private var vm: SwapViewModel
    @State private var maticText = "0.05"
    @State private var usdcText = "2.0"
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case matic, usdc
    }
    
    init() {
        let splitService = SplitSwapService(
            quoteService:   OneInchQuoteService(),
            swapService:    OneInchSwapService(),
            approveService: ApproveService(),
            txSender:       .shared
        )
        _vm = StateObject(wrappedValue: SwapViewModel(splitService: splitService))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            
            if let q = vm.quote {
                Text("From \(formatAmount(weiString: q.inWei, decimals: q.inDecimals)) \(q.inSymbol)")
                Text("To   \(formatAmount(weiString: q.outWei, decimals: q.outDecimals)) \(q.outSymbol)")
            }
            
            Button("Get Quote (USDC→WETH, 1 USDC)") {
                vm.getQuoteUSDCtoWETH(amountUSDC: 1)
            }
            .buttonStyle(.bordered)
            
            Divider().padding(.vertical, 8)
            
            // D2: MATIC → USDC
            VStack(spacing: 8) {
                HStack {
                    Text("MATIC → USDC")
                    Spacer()
                }
                
                TextField("Amount (MATIC)", text: $maticText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .matic)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    let amt = Decimal(string: maticText) ?? 0
                    vm.swapMaticToUsdc(amountMatic: amt)
                } label: {
                    if vm.isBuilding || vm.isSending {
                        ProgressView()
                    } else {
                        Text("Swap MATIC→USDC")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isBuilding || vm.isSending)
            }
            
            Divider().padding(.vertical, 8)
            
            // D3: USDC → WETH (approve → swap)
            VStack(spacing: 8) {
                HStack {
                    Text("USDC → WETH")
                    Spacer()
                }
                
                TextField("Amount (USDC)", text: $usdcText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .usdc)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    let amt = Decimal(string: usdcText) ?? 0
                    print("USDC→WETH: \(amt)")
                    vm.executeSwapUSDCtoWETH(amount: amt)
                } label: {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        Text("Swap USDC→WETH")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)
            }
            
            Divider().padding(.vertical, 8)
            // D4: Split USDC → WETH (just stub)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Split options")
                    Spacer()
                }
//                Stepper("Parts: \(vm.selectedParts)", value: $vm.selectedParts, in: 1...5, step: 1)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split USDC → WETH").font(.headline)

                    Button("Рассчитать лучшие N") {
                        let amt = Decimal(string: usdcText) ?? 0
                        vm.simulateSplitQuotes(from: Tokens.usdcNative, to: Tokens.weth, amount: amt, maxParts: 5)
                    }
                    .buttonStyle(.bordered)

                    if !vm.splitResults.isEmpty {
                        ForEach(vm.splitResults, id: \.parts) { res in
                            HStack {
                                Text("\(res.parts)x")
                                Spacer()
                                Text(String(format: "%.6f WETH",
                                            NSDecimalNumber(decimal: res.totalToTokenAmount).doubleValue))
                                let diff = res.deltaVsOnePart
                                let pct  = (res.totalToTokenAmount == 0 || vm.splitResults.first?.totalToTokenAmount == 0)
                                           ? 0.0
                                           : (NSDecimalNumber(decimal: diff).doubleValue /
                                              NSDecimalNumber(decimal: vm.splitResults.first!.totalToTokenAmount).doubleValue * 100.0)
                                Text(diff >= 0
                                     ? String(format: "+%.6f WETH (%.3f%%)", diff.doubleValue, pct)
                                     : String(format: "%.6f WETH (%.3f%%)", diff.doubleValue, pct))
                                .foregroundColor(diff >= 0 ? .green : .red)
                            }
                            .font(res.parts == (vm.bestSplit?.parts ?? -1) ? .headline : .body)
                        }

                        HStack {
                            Text("Selected parts: \(vm.selectedParts)")
                            Slider(value: Binding(
                                get: { Double(vm.selectedParts) },
                                set: { vm.selectedParts = Int($0) }
                            ), in: 1...5, step: 1)
                        }
                        Toggle("Force split even if loss", isOn: $vm.forceSplitEvenIfLoss)
                    }
                }

                
                
                Button("Swap with Split") {
                    let amt = Decimal(string: usdcText) ?? 0
                    if vm.selectedParts <= 1 {
                        vm.executeSwapUSDCtoWETH(amount: amt)
                    } else {
                        vm.startSplitSwapUSDCtoWETH(
                            totalAmount: amt,
                            parts: vm.selectedParts,
                            slippageBps: 100
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading || vm.isSplitRunning)
                
                if vm.isSplitRunning {
                    if let t = vm.splitProgressText { Text(t).font(.footnote) }
                    ProgressView(value: Double(vm.splitCurrent), total: Double(max(vm.splitTotal, 1)))
                        .progressViewStyle(.linear)
                    Button(role: .destructive) { vm.cancelSplit() } label: { Text("Stop") }
                }
                
                if !vm.splitHashes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Split tx hashes:")
                            .font(.subheadline).bold()
                        ForEach(vm.splitHashes, id: \.self) { h in
                            HStack {
                                Text(h).font(.footnote).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Link("View", destination: URL(string: "https://polygonscan.com/tx/\(h)")!)
                            }
                        }
                    }
                }

            }
            //            Button("Swap with Split") {
            //                let amt = Decimal(string: usdcText) ?? 0
            //                if vm.selectedParts <= 1 || (!vm.forceSplitEvenIfLoss && vm.bestSplit?.parts == 1) {
            //                    vm.executeSwapUSDCtoWETH(amount: amt) // обычный своп
            //                } else {
            //                    vm.startSplitSwapUSDCtoWETH(totalAmount: amt, parts: vm.selectedParts, slippageBps: 100)
            //                }
            //            }
            //            .disabled(vm.isLoading || vm.isSplitRunning)
            //
            //            if vm.isSplitRunning {
            //                if let t = vm.splitProgressText { Text(t).font(.footnote) }
            //                ProgressView(value: Double(vm.splitCurrent), total: Double(vm.splitTotal))
            //                    .progressViewStyle(.linear)
            //                Button(role: .destructive) { vm.cancelSplit() } label: { Text("Stop") }
            //            }
            
            //            VStack(alignment: .leading, spacing: 8) {
            //                Text("Split USDC → WETH")
            //                    .font(.headline)
            //                Button("Рассчитать лучшие N") {
            //                    let amt = Decimal(string: usdcText) ?? 0
            //                    vm.simulateSplitQuotes(from: Tokens.usdcNative, to: Tokens.weth, amount: amt, maxParts: 5)
            //                }
            //                .buttonStyle(.bordered)
            //
            //                if !vm.splitResults.isEmpty {
            //                    // results
            //                    ForEach(vm.splitResults, id: \.parts) { res in
            //                        HStack {
            //                            Text("\(res.parts)x")
            //                            Spacer()
            //                            Text(String(format: "%.4f %@",
            //                                        NSDecimalNumber(decimal: res.totalToTokenAmount).doubleValue,
            //                                        "WETH"))
            //
            //                            let diff = res.deltaVsOnePart
            //                            Text(diff >= 0
            //                                 ? "+\(NSDecimalNumber(decimal: diff).doubleValue) WETH"
            //                                 : "\(NSDecimalNumber(decimal: diff).doubleValue) WETH")
            //                                .foregroundColor(diff >= 0 ? .green : .red)
            //                        }
            //                        .font(res.parts == (vm.bestSplit?.parts ?? -1) ? .headline : .body)
            //                    }
            //
            //                    HStack {
            //                        Text("Выбранные части: \(vm.selectedParts)")
            //                        Slider(
            //                            value: Binding(
            //                                get: { Double(vm.selectedParts) },
            //                                set: { vm.selectedParts = Int($0) }
            //                            ),
            //                            in: 1...5,
            //                            step: 1
            //                        )
            //                        .disabled(!vm.forceSplitEvenIfLoss && vm.bestSplit?.parts == 1)
            //                    }
            //
            //                    Toggle("Force split even if loss", isOn: $vm.forceSplitEvenIfLoss)
            //                    Button("Swap with Split") {
            //                        let amt = Decimal(string: usdcText) ?? 0
            //                        if vm.selectedParts <= 1 || (!vm.forceSplitEvenIfLoss && vm.bestSplit?.parts == 1) {
            //                            vm.executeSwapUSDCtoWETH(amount: amt)
            //                        } else {
            //                            vm.executeSwapUSDCtoWETH(amount: amt)
            //                        }
            //                    }
            //                    .buttonStyle(.borderedProminent)
            //                    .disabled(vm.isLoading)
            //                }
            //            }
            
            
//            if let hash = vm.txHash {
//                Text("Tx: \(hash)")
//                    .font(.footnote)
//                    .lineLimit(1)
//                    .truncationMode(.middle)
//                Link("Open in Polygonscan",
//                     destination: URL(string: "https://polygonscan.com/tx/\(hash)")!)
//            }
            
            if let err = vm.error { Text(err).foregroundColor(.red) }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            print("tapped")
            focusedField = nil
        }
        .padding()
    }
}

