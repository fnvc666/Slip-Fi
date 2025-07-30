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
        ZStack {
            Image("connectBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 30) {
                
                HStack {
                    Text("Slip-Fi")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                .padding(25)
                
                Spacer()
                
                Text("Welcome to Slip-Fi — optimize your\n swaps")
                    .font(.system(size: 20, weight: .thin))
                    .foregroundStyle(Color(red: 0.82, green: 0.88, blue: 0.87))
                    .multilineTextAlignment(.leading)
                
                Button {
                    AppKit.present()
                } label: {
                    HStack {
                        Text("Connect Wallet")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.black)
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack() {
                    Spacer()
                    Text("Powered by Pavel Sivak & 1inch API's")
                        .font(.system(size: 12, weight: .thin))
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                }
                
                .padding(.bottom, 25)
                
            }
            .padding(.horizontal, 25)
        }
    }
}

#Preview {
    ConnectView()
}
