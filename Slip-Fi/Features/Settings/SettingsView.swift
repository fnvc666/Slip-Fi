//
//  SettingsView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var session: SessionStore
    @State private var addressCopied = false
    @State private var isAlertShown = false
    
    private var accountAddress: String = UserDefaults.standard.string(forKey: "accountAddress") ?? "0x1C9e3253CF6629e692FcCE047e26E131CeAa3c08"
    
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
                                    UIPasteboard.general.string = accountAddress
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
                                session.disconnect()
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
