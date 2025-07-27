//
//  ContentView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case yuutaiSakimawari
    case ipo
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .yuutaiSakimawari: return "優待"
        case .ipo: return "IPO"
        }
    }
    
    var icon: String {
        switch self {
        case .yuutaiSakimawari: return "gift.fill"
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
                    YuutaiMonthView()
                        .tabItem {
                            Label(AppTab.yuutaiSakimawari.title, systemImage: AppTab.yuutaiSakimawari.icon)
                        }
                        .tag(AppTab.yuutaiSakimawari)

                case .ipo:
                    IPOListView()
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
