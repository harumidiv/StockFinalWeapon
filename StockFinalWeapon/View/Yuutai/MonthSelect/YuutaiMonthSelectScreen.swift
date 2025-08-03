//
//  YuutaiMonthSelectScreen.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/13.
//

import SwiftUI

struct SelectedMonth: Identifiable, Equatable, Hashable {
    let id = UUID()
    let ja: String
    let en: String
}

struct YuutaiMonthSelectScreen: View {
    
    private let months: [SelectedMonth] = [
        .init(ja: "1月", en: "january"),
        .init(ja: "2月", en: "february"),
        .init(ja: "3月", en: "march"),
        .init(ja: "4月", en: "april"),
        .init(ja: "5月", en: "may"),
        .init(ja: "6月", en: "june"),
        .init(ja: "7月", en: "july"),
        .init(ja: "8月", en: "august"),
        .init(ja: "9月", en: "september"),
        .init(ja: "10月", en: "october"),
        .init(ja: "11月", en: "november"),
        .init(ja: "12月", en: "december")
    ]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    @State private var selectedMonth: SelectedMonth? = nil
    @State private var purchaseDate: Date = Date()
    @State private var saleDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var code: String = ""
    
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section(header: Text("日付選択(年は適当でOK)")) {
                    DatePicker("購入日", selection: $purchaseDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    DatePicker("売却日", selection: $saleDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                
                Section(header: Text("優待券権利月選択")) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(months, id: \.id) { month in
                            Button(action: {
                                path.append(month)  // ← SelectedMonthをpush
                            }) {
                                Text(month.ja)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                
                Section(header: Text("単体銘柄")) {
                    NavigationLink(destination: YuutaiAnticipationView(code: $code, purchaseDate: $purchaseDate, saleDate: $saleDate)) {
                        Text("勝率スクリーニング")
                    }
                }
            }
            .navigationTitle("優待先周り")
            .navigationDestination(for: SelectedMonth.self) { month in
                YuutaiMonthDetailView(
                    purchaseDate: $purchaseDate,
                    saleDate: $saleDate,
                    month: month
                )
            }
        }
    }
}

#Preview {
    YuutaiMonthSelectScreen()
}

