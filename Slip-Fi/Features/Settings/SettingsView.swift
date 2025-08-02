//
//  SettingsView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import SwiftUI

struct SettingsView: View {
    private var accountAddress: String = UserDefaults.standard.string(forKey: "accountAddress") ?? "0x111111125421cA6dc452d289314280a0f8842A65"
    @State private var addressCopied = false
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Text("Settings")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                
                List {
                    Section {
                        HStack {
                            Text(accountAddress)
                                .font(.system(size: 11, weight: .light))
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    addressCopied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    withAnimation {
                                        addressCopied = false
                                    }
                                }
                                
                            } label: {
                                Image(systemName: addressCopied ? "document.fill" : "document")
                                    .tint(.black)
                            }
                        }
                        HStack {
                            Text("Change Wallet")
                                .font(.system(size: 14, weight: .light))
                            
                            Spacer()
                            
                            Button {
                                UIPasteboard.general.string = accountAddress
                            } label: {
                                Image(systemName: "wallet.bifold")
                                    .tint(.black)
                            }
                        }
                    } header: {
                        Text("Wallet")
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(Color(red: 0.98, green: 0.98, blue: 0.98).opacity(0.1))
                }
                .foregroundStyle(Color.white)
                .scrollContentBackground(.hidden)
                
                Spacer()
            }
        }
        .background(Color(red: 0.04, green: 0.07, blue: 0.09))
    }
}

#Preview {
    SettingsView()
}
