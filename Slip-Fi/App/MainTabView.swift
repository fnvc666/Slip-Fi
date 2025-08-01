//
//  MainTabView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    var body: some View {
        ZStack {
            switch selectedTab {
                case .home:
                    SwapView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
            }

            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 24)
                
            }
            .frame(maxWidth: 250)
        }
    }
}


#Preview {
    MainTabView()
}
