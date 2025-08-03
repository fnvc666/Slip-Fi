//
//  Slip_FiApp.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import SwiftUI
import ReownAppKit
import WalletConnectNetworking
import Starscream

@main
struct Slip_FiApp: App {
    @StateObject private var session = SessionStore()
    
    init() {
        // Networking init
        Networking.configure(
            groupIdentifier: Secrets.groupIdentifier,
            projectId: Secrets.appKitProjectId,
            socketFactory: StarscreamSocketFactory()
        )
        
        // AppKit init
        let crypto = DummyCryptoProvider()
        let metadata = AppMetadata(
            name: "Slip-Fi",
            description: "Swap optimizer",
            url: "https://github.com/fnvc666/Slip-Fi",
            icons: ["https://avatars.githubusercontent.com/u/179229932"],
            redirect: try! AppMetadata.Redirect(native: "slipfi://", universal: nil)
            )
        
        AppKit.configure(
            projectId: Secrets.appKitProjectId,
            metadata: metadata,
            crypto: crypto,
            authRequestParams: nil
        )
    }
    
    
    var body: some Scene {
        WindowGroup {
            if session.isConnected {
                MainTabView()
                    .environmentObject(session)
            } else {
                ConnectView()
            }
        }
    }
}

enum Secrets {
    private static let values: NSDictionary = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) else {
            fatalError("Couldn't load Secrets.plist")
        }
        return dict
    }()
    
    static func value(for key: String) -> String {
        guard let value = values[key] as? String else {
            fatalError("Missing key: \(key) in Secrets.plist")
        }
        return value
    }
    
    static var appKitProjectId = value(for: "AppKitProjectId")
    static var groupIdentifier = value(for: "GroupIdentifier")
    static let oneInchKey = value(for: "OneInchApiKey")
}
