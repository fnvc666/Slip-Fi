//
//  MainTabView.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import SwiftUI

struct MainTabView: View {
    
    @State private var selectedTab: Tab = .home
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        contentView
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer(minLength: 0)
                    CustomTabBar(selectedTab: $selectedTab)
                        .frame(maxWidth: 250)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
            case .home:
                SwapView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
                    .environmentObject(session)
        }
    }
}

#Preview {
    MainTabView()
}
