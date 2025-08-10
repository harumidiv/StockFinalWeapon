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
    
    @State private var showingYuutaiCacheAlert = false
    @State private var showingYuutaiInfoCacheAlert = false
    @State private var selectedMonth: YuutaiMonth?
    
    var body: some View {
        Form {
            
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
                
                Button(action: {
                    showingYuutaiInfoCacheAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("楽しい優待配当生活")
                    }
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
        .alert("楽しい優待配当生活キャッシュをクリアしますか？", isPresented: $showingYuutaiInfoCacheAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("クリア", role: .destructive) {
                UserStore.deleteYuutaiInfo()
            }
        } message: {
            Text("アプリのパフォーマンスが改善される場合があります。")
        }
        .alert("\(selectedMonth?.ja ?? "全ての")キャッシュをクリアしますか？", isPresented: $showingYuutaiCacheAlert) {
            Button("キャンセル", role: .cancel) {
                self.selectedMonth = nil
            }
            Button("クリア", role: .destructive) {
                Task {
                    do {
                        let cacheData: [YuutaiSakimawariChartModel]
                        
                        if let selectedMonth {
                            let descriptor = FetchDescriptor<YuutaiSakimawariChartModel>()
                            let allData = try? context.fetch(descriptor)
                            cacheData = allData?.filter { $0.month == selectedMonth } ?? []
                            
                        } else {
                            UserStore.deleteYuutaiInfo()
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
