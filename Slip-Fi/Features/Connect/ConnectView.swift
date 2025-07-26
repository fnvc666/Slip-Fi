//
//  ConnectView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//
import SwiftUI
import ReownAppKit

struct ConnectView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        VStack {
            Text("Optimize your swaps on Polygon using 1inch APIs")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button {
                AppKit.present()
            } label: {
                Text("Connect Wallet")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.blue, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ConnectView()
}
