//
//  MainTabView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Swap", systemImage: "house") {
                SwapView()
            }
            
            Tab("History", systemImage: "pencil") {
                SwapView()
            }
            
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
