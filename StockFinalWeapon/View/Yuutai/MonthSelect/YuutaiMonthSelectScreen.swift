//
//  YuutaiMonthSelectScreen.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/13.
//

import SwiftUI

enum YuutaiMonth: String, CaseIterable, Identifiable, Codable {
    case january
    case february
    case march
    case april
    case may
    case june
    case july
    case august
    case september
    case october
    case november
    case december
    
    var id: Self { self }
    
    var ja: String {
        switch self {
        case .january:
            return "1月"
        case .february:
            return "2月"
        case .march:
            return "3月"
        case .april:
            return "4月"
        case .may:
            return "5月"
        case .june:
            return "6月"
        case .july:
            return "7月"
        case .august:
            return "8月"
        case .september:
            return "9月"
        case .october:
            return "10月"
        case .november:
            return "11月"
        case .december:
            return "12月"
        }
    }
}

struct YuutaiMonthSelectScreen: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    @State private var selectedMonth: YuutaiMonth? = nil
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
                        ForEach(YuutaiMonth.allCases) { month in
                            Button(action: {
                                path.append(month)
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
            .navigationDestination(for: YuutaiMonth.self) { month in
                YuutaiMonthWinningRateListScreen(
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

