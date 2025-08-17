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
    case mypage
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .yuutaiSakimawari: return "優待"
        case .trailing: return "トレイリング"
        case .ipo: return "IPO"
        case .mypage: return "マイページ"
        }
    }
    
    var icon: String {
        switch self {
        case .yuutaiSakimawari: return "gift.fill"
        case .trailing: return "waveform.path.ecg"
        case .ipo: return "sparkles"
        case .mypage: return "person.fill"
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
                let calender = Calendar.current
                let year = calender.component(.year, from: Date())
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd"
                let list = YuutaiDateChecker.shareholderBenefitEligibleDays(in: year)
                scheduleLocalNotification(dates: list)
            }
        }
    }
    
    func scheduleLocalNotification(dates: [Date]) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            
            if granted {
                dates.forEach { date in
                    let calender = Calendar.current
                    let year = calender.component(.year, from: date)
                    let month = calender.component(.month, from: date)
                    let day = calender.component(.day, from: date)
                    let dateComponents = DateComponents(year: year, month: month, day: day, hour: 19)
                    
                    let content = UNMutableNotificationContent()
                    content.title = "優待権利付き最終日"
                    content.body = "現渡しわすれてない？"
                    content.sound = UNNotificationSound.default
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                    
                    let request = UNNotificationRequest(identifier: month.description, content: content, trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { (error) in
                        if let error = error {
                            print("⚠️通知のスケジュールに失敗しました: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                print("⚠️通知の許可が拒否されました。")
            }
        }
    }
}


#Preview {
    HomeTabView()
}
