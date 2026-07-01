//
//  ContentView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case sndkDiff
    case momentam
    case winRate
    case intradayWinRate
    case yuutaiSakimawari
    case trailing
    case ipo
    case jQuants
    case mypage

    var id: Self { self }

    var title: String {
        switch self {
        case .yuutaiSakimawari: return "優待"
        case .trailing: return "トレイリング"
        case .ipo: return "IPO"
        case .jQuants: return "JQuants"
        case .momentam: return "モメンタム"
        case .sndkDiff: return "SNDK差分"
        case .winRate: return "勝率"
        case .intradayWinRate: return "デイトレ"
        case .mypage: return "マイページ"
        }
    }

    var icon: String {
        switch self {
        case .yuutaiSakimawari: return "gift.fill"
        case .trailing: return "waveform.path.ecg"
        case .ipo: return "sparkles"
        case .jQuants: return "chart.bar.fill"
        case .momentam: return "bolt.fill"
        case .sndkDiff: return "arrow.left.arrow.right"
        case .winRate: return "percent"
        case .intradayWinRate: return "sun.max.fill"
        case .mypage: return "person.fill"
        }
    }
}

struct HomeTabView: View {
    @State private var selectedTab: AppTab = .sndkDiff
    
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
                    
                case .jQuants:
                    Sector33SelectScreen()
                        .tabItem {
                            Label(AppTab.jQuants.title, systemImage: AppTab.jQuants.icon)
                        }
                        .tag(AppTab.jQuants)
                    
                case .momentam:
                    MomentamRankingScreen()
                        .tabItem {
                            Label(AppTab.momentam.title, systemImage: AppTab.momentam.icon)
                        }
                        .tag(AppTab.momentam)
                case .sndkDiff:
                    SNDKDiffScreen()
                        .tabItem {
                            Label(AppTab.sndkDiff.title, systemImage: AppTab.sndkDiff.icon)
                        }
                        .tag(AppTab.sndkDiff)
                case .winRate:
                    OvernightWinRateScreen(strategy: .overnight)
                        .tabItem {
                            Label(AppTab.winRate.title, systemImage: AppTab.winRate.icon)
                        }
                        .tag(AppTab.winRate)
                case .intradayWinRate:
                    OvernightWinRateScreen(strategy: .intraday)
                        .tabItem {
                            Label(AppTab.intradayWinRate.title, systemImage: AppTab.intradayWinRate.icon)
                        }
                        .tag(AppTab.intradayWinRate)
                case .mypage:
                    MypageScreen()
                        .tabItem {
                            Label(AppTab.mypage.title, systemImage: AppTab.mypage.icon)
                        }
                        .tag(AppTab.mypage)
                }
            }
            .background(.ultraThinMaterial)
        }
        .onAppear {
            if UserStore.yuutaiRecordDatePushNotification {
                YuutaiDateChecker.scheduleYuutaiLocalNotification()
            }
        }
    }
    
    
}


#Preview {
    HomeTabView()
}
