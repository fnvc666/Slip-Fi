//
//  SwapView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//
import SwiftUI

struct SwapView: View {
    @StateObject private var vm = SwapViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            if let q = vm.quote {
                Text("From \(formatAmount(weiString: q.inWei(fallback: vm.lastAmountWei), decimals: q.inDecimals)) \(q.inSymbol)")
                Text("To   \(formatAmount(weiString: q.outWei, decimals: q.outDecimals)) \(q.outSymbol)")
            } else {
                Text("Press the button to get a live quote")
            }
            
            Button("Get Quote (USDC→WETH, 1 USDC)") {
                vm.getQuoteUSDCtoWETH(amountUSDC: 1)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .alert("Error", isPresented: .constant(vm.error != nil), actions: { Button("OK"){ vm.error = nil }}, message: { Text(vm.error ?? "") })
    }
}
