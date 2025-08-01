//
//  HistoryView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import SwiftUI

struct HistoryView: View {
    var transactions: [TransactionModel] = []
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading) {
                    HStack {
                        Text("History")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                        
                        Spacer()
                    }
                    .padding(.bottom, 32)
                    
                    ForEach(transactions, id: \.self) { trans in
                        TransactionBox(transaction: trans)
                    }
                    
                }
                .padding(16)
            }
        }
        .background(Color(red: 0.04, green: 0.07, blue: 0.09))
//        .ignoresSafeArea(edges: .top)
    }
}

struct TransactionBox: View {
    
    var transaction: TransactionModel
    
    private static let dateFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "MM/dd/yyyy"
      return f
    }()
    var formattedDate: String {
      Self.dateFormatter.string(from: transaction.date)
    }

    
    var body: some View {
        VStack {
            HStack {
                Text(formattedDate)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.98).opacity(0.7))
                Spacer()
            }
            HStack {
                Text("\(String(format: "%.2f", transaction.fromAmount)) \(transaction.fromToken)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white)
                
                Text(String(format: "%.6f", transaction.toAmount))
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.02, green: 0.84, blue: 0.71))
                
                Text("\(transaction.toToken)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color(red: 0.74, green: 0.76, blue: 0.78).opacity(0.2))
            
            HStack {
                Text("TX")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.98, green: 0.98, blue: 0.98).opacity(0.7))
                Spacer()
            }
            .padding(.top, 12)
            
            HStack {
                ForEach(transaction.txArray, id: \.self) { trans in
                    Text(trans)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 60)
                        .padding(.trailing, 4)
                }
                Spacer()
                
                Button {
                    // view button, link to tx
                } label: {
                    Text("View")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.05, green: 0.13, blue: 0.2))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 360, maxHeight: 166)
    }
}

struct TransactionModel: Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var fromToken: String
    var fromAmount: Double
    var toToken: String
    var toAmount: Double
    var txArray: [String] = []
}


#Preview {
    var transaction1 = TransactionModel(date: Date.now, fromToken: "USDC", fromAmount: 100, toToken: "WETH", toAmount: 0.0282024419, txArray: [
        "0x1d1fd6afdcd933d913516ef4a4606f63dc1c49c67f006e6173e8d6ad4801088a",
        "0xc82223184d99e4bdbdd935ec366b82e5016d93e4f8fa7b961a8b958765698a93",
        "0x1ff5d262c4d4baaf433570772bf7237e598fe24c52741b19d21ded5cc19ebd8c"])
    HistoryView(transactions: [transaction1])
}
