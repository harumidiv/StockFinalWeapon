//
//  ContentView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case yuutaiSakimawari
    case trailing
    case ipo
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .yuutaiSakimawari: return "優待"
        case .trailing: return "トレイリング"
        case .ipo: return "IPO"
        }
    }
    
    var icon: String {
        switch self {
        case .yuutaiSakimawari: return "gift.fill"
        case .trailing: return "waveform.path.ecg"
        case .ipo: return "sparkles"
        }
    }
}

struct HomeTabView: View {
    @State private var selectedTab: AppTab = .yuutaiSakimawari
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                switch tab {
                case .yuutaiSakimawari:
                    YuutaiMonthSelectScreen()
                        .tabItem {
                            Label(AppTab.yuutaiSakimawari.title, systemImage: AppTab.yuutaiSakimawari.icon)
                        }
                        .tag(AppTab.yuutaiSakimawari)
                case .trailing:
                    TrailingConditionsScreen()
                        .tabItem {
                            Label(AppTab.trailing.title, systemImage: AppTab.trailing.icon)
                        }
                case .ipo:
                    IPOFluctuationRateScreen()
                        .tabItem {
                            Label(AppTab.ipo.title, systemImage: AppTab.ipo.icon)
                        }
                        .tag(AppTab.ipo)
                }
            }
            .background(.ultraThinMaterial)
        }
    }
}


#Preview {
    HomeTabView()
}
