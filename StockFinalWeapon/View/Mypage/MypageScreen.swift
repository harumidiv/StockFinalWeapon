//
//  MypageScreen.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/10.
//

import SwiftUI
import SwiftData

struct MypageScreen: View {
    @Environment(\.modelContext) private var context
    @AppStorage(UserStore.Key.yuutaiRecordDatePushNotification.rawValue) var yuutaiRecordDatePushNotification: Bool  = false
    
    @State private var showingYuutaiCacheAlert = false
    @State private var showingYuutaiInfoCacheAlert = false
    @State private var selectedMonth: YuutaiMonth?
    
    var body: some View {
        Form {
            Section(header: Text("通知設定")) {
                Toggle("権利付き最終日お知らせ通知", isOn: $yuutaiRecordDatePushNotification)
            }
            .onChange(of: yuutaiRecordDatePushNotification) { oldValue, newValue in
                if newValue {
                    YuutaiDateChecker.scheduleYuutaiLocalNotification()
                } else {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                }
            }
            
            Section(header: Text("優待先周り📈データキャッシュ")) {
                Button(action: {
                    showingYuutaiCacheAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("すべてのキャッシュデータをクリア")
                    }
                    .foregroundColor(.red)
                }
                
                ForEach(YuutaiMonth.allCases) { month in
                    Button(action: {
                        showingYuutaiCacheAlert = true
                        selectedMonth = month
                    }) {
                        Text("\(month.ja)優待キャッシュ")
                    }
                    
                }
                .onDelete(perform: { indexSet in
                    // indexSetを使って該当する月のキャッシュを削除する処理を記述
                })
            }
        }
        .navigationTitle("マイページ")
        .alert("\(selectedMonth?.ja ?? "全ての")キャッシュをクリアしますか？", isPresented: $showingYuutaiCacheAlert) {
            Button("キャンセル", role: .cancel) {
                self.selectedMonth = nil
            }
            Button("クリア", role: .destructive) {
                Task {
                    do {
                        let cacheData: [YuutaiSakimawariChartModel]
                        
                        if let selectedMonth {
                            UserStore.deleteYuutaiInfo(month: selectedMonth)
                            let descriptor = FetchDescriptor<YuutaiSakimawariChartModel>()
                            let allData = try? context.fetch(descriptor)
                            cacheData = allData?.filter { $0.month == selectedMonth } ?? []
                            
                        } else {
                            UserStore.deleteAllYuutaiInfo()
                            let fetchDescriptor = FetchDescriptor<YuutaiSakimawariChartModel>()
                            cacheData = try context.fetch(fetchDescriptor)
                        }
                        
                        for cache in cacheData {
                            context.delete(cache)
                        }
                        
                        try context.save()
                        self.selectedMonth = nil
                        
                    } catch {
                        print("Failed to fetch item: \(error)")
                    }
                }
            }
        } message: {
            Text("アプリのパフォーマンスが改善される場合があります。")
        }
    }
}

#Preview {
    MypageScreen()
}

