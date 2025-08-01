//
//  CustomTabBar.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 31/07/2025.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    
    var body: some View {
        HStack {
                tabButton(tab: .home, icon: "arrow.left.arrow.right", title: "Swap")
            tabButton(tab: .history, icon: "clock.arrow.circlepath", title: "History")
                tabButton(tab: .settings, icon: "slider.horizontal.3", title: "Settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 10)
        }
    
    private func tabButton(tab: Tab, icon: String, title: String) -> some View {
            Button {
                selectedTab = tab
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                    
                    if selectedTab == tab {
                        Text(title)
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.1))
            .clipShape(Capsule())
        }
}

enum Tab: Hashable {
    case home, history, settings
}
