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
    @State private var showSplitTable = false
    @FocusState private var focusedField: FocusedField?
    
    @State private var testEth = "0"
    
    private var accountAddress: String = UserDefaults.standard.string(forKey: "accountAddress") ?? "0x111111125421cA6dc452d289314280a0f8842A65"
    
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
        ZStack {
            Image("swapBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // header
                    HStack {
                        Text("Slip-Fi")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        HStack {
                            Text(accountAddress)
                                .truncationMode(.middle)
                                .font(.system(size: 15, weight: .thin))
                                .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.98).opacity(0.5))
                                .frame(width: 90, height: 18)
                            
                            Button {
                                UIPasteboard.general.string = accountAddress
                            } label: {
                                Image(systemName: "square.on.square")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    
                    Text("Transaction")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.white)
                        .padding(.top, 16)
                    
                    // Pay & Receive
                    ZStack {
                        VStack(spacing: 16) {
                            SwapBox(
                                amount: $vm.payText,
                                backgroundImage: "youPayBackground",
                                option: "You pay",
                                balance: String(format: "%.2f", vm.isUsdcToWeth ? vm.usdcBalance.doubleValue : vm.wethBalance.doubleValue),
                                token: vm.isUsdcToWeth ? "USDC" : "WETH",
                                tokenImage: vm.isUsdcToWeth ? "usdc" : "weth")
                            
                            SwapBox(
                                amount: .constant(vm.quote == nil ? "" : formatAmount(weiString: vm.quote!.outWei, decimals: vm.isUsdcToWeth ? 18 : 6)),
                                backgroundImage: "youReceiveBackground",
                                option: "You Receive",
                                balance: String(format: "%.2f", vm.isUsdcToWeth ? vm.wethBalance.doubleValue : vm.usdcBalance.doubleValue),
                                token: vm.isUsdcToWeth ? "WETH" : "USDC",
                                tokenImage: vm.isUsdcToWeth ? "weth" : "usdc")
                        }
                        
                        Button {
                            withAnimation { vm.switchDirection() }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 19))
                                .foregroundStyle(.black)
                                .frame(width: 35, height: 35)
                                .padding(4)
                                .background(.white)
                                .clipShape(Circle())
                        }
                    }
                    
                    SplitStack(vm: vm, usdcAmount: vm.payText)
                    
                    if vm.splitResults.isEmpty {
                        Button {
                            showSplitTable = true
                            let amt = Decimal(string: vm.payText) ?? 0
                            vm.simulateSplitQuotes(from: Tokens.usdcNative, to: Tokens.weth, amount: amt, maxParts: 5)
                        } label: {
                            HStack {
                                Spacer()
                                
                                if vm.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Swap")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(red: 0.05, green: 0.13, blue: 0.2))
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 8)
                    }
                    
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    print("tapped")
                    focusedField = nil
                }

                .padding(.top, 15)
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 45)
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    SwapView()
}

struct SwapBox: View {
    @Binding var amount: String
    var backgroundImage: String
    var isLoading = false
    var option: String
    var balance: String
    var token: String
    var tokenImage: String
    var body: some View {
        ZStack {
            Image(backgroundImage)
                .resizable()
                .scaledToFill()
            HStack {
                VStack(alignment: .leading) {
                    Text(option)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.74, green: 0.76, blue: 0.78))
                    TextField("amount", text: $amount)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.98))
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .leading)
                        .padding(.top, 5)
                    
                    Text("$\(balance)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.74, green: 0.76, blue: 0.78))
                        .padding(.top, 15)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack {
                    Spacer()
                    
                    Button {
                        
                    } label: {
                        HStack {
                            Image(tokenImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text(token)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 110, height: 32)
                    .background(.white.opacity(0.3))
                    .clipShape(Capsule())
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: 140)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct SplitStack: View {
    @ObservedObject var vm: SwapViewModel
    var usdcAmount: String
    var body: some View {
        VStack {
            if !vm.splitResults.isEmpty {
                LazyVStack {
                    ForEach(Array(vm.splitResults.enumerated()), id: \.element.parts) { index, res in
                        SplitResultRow(vm: vm, result: res)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .font(res.parts == (vm.bestSplit?.parts ?? -1) ? .headline : .body)
                        
                        if index < vm.splitResults.count - 1 {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack {
                    Text("Selected splits number")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.98))
                    
                    Spacer()
                    
                    HStack(spacing: 0) {
                        ForEach(1..<6, id: \.self) { number in
                            Button {
                                vm.selectedParts = number
                            } label: {
                                Text("\(number)")
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(number == vm.selectedParts ? .white : .white.opacity(0.1))
                                    .foregroundColor(number == vm.selectedParts ? .black : .white)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.top, 24)
                
                HStack(spacing: 16) {
                    
                    Spacer()
                    
                    Button {
                        let amt = Decimal(string: usdcAmount)
                        vm.executeSwapUSDCtoWETH(amount: amt ?? 0)
                    } label: {
                        Text("Swap without Split")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        let amt = Decimal(string: usdcAmount) ?? 0
                        if vm.selectedParts <= 1 {
                            vm.executeSwapUSDCtoWETH(amount: amt)
                        } else {
                            vm.startSplitSwapUSDCtoWETH(
                                totalAmount: amt,
                                parts: vm.selectedParts,
                                slippageBps: 100
                            )
                        }
                    } label: {
                        Text("Swap with Split")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 24)
            }
        }
    }
}

struct SplitResultRow: View {
    @ObservedObject var vm: SwapViewModel
    var result: SplitResult
    var body: some View {
        HStack {
            Text("\(result.parts) split")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.46, green: 0.5, blue: 0.52))
            
            Spacer()
            
            Text(String(format: "%.4f WETH",
                        NSDecimalNumber(decimal: result.totalToTokenAmount).doubleValue))
            .font(.system(size: 14))
            .foregroundStyle(Color(red: 0.04, green: 0.07, blue: 0.09))
            
            let diff = result.deltaVsOnePart
            let pct  = (result.totalToTokenAmount == 0 || vm.splitResults.first?.totalToTokenAmount == 0)
            ? 0.0
            : (NSDecimalNumber(decimal: diff).doubleValue /
               NSDecimalNumber(decimal: vm.splitResults.first!.totalToTokenAmount).doubleValue * 100.0)
            Text(diff >= 0
                 ? String(format: "+%.4f WETH (%.3f%%)", diff.doubleValue, pct)
                 : String(format: "%.4f WETH (%.3f%%)", diff.doubleValue, pct))
            .multilineTextAlignment(.trailing)
            .font(.system(size: 14))
            .foregroundColor(diff >= 0 ? Color(red: 0.02, green: 0.68, blue: 0.57).opacity(0.8) : Color(red: 0.68, green: 0.02, blue: 0.03).opacity(0.8))
        }
    }
}
