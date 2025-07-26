//
//  SessionStore.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import Foundation
import Combine
import ReownAppKit

@MainActor
final class SessionStore: ObservableObject {
    @Published var isConnected = false
    @Published var address: String?

    private var bag = Set<AnyCancellable>()

    init() {
        if let account = AppKit.instance.getAddress() {
            self.isConnected = true
            self.address = account
        }
        
        // settle session
        AppKit.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.isConnected = true
                self?.address = session.accounts.first?.address
            }
            .store(in: &bag)

        // delete session
        AppKit.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isConnected = false
                self?.address = nil
            }
            .store(in: &bag)
    }
    
    func restoreSession() async {
        try! await AppKit.instance.connect(walletUniversalLink: "")
    }
}
