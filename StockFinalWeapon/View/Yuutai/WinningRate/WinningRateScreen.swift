//
//  YuutaiAnticipationView.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/07.
//

import Foundation
import SwiftUI
import SwiftYFinance

struct YuutaiAnticipationView: View {
    @State private var stockChartPairData: [StockChartPairData] = []
    @Binding var code: String
    @Binding var purchaseDate: Date
    @Binding var saleDate: Date
    var yuutai: String?
    @State private var errorText: String = "銘柄コードを入力してください"
    @FocusState private var isFocused: Bool
    
    // 前の画面から渡された時の初回読み込み
    @State private var hasAppeared = false
    
    var body: some View {
        Form {
            Section(header: Text("銘柄入力")) {
                TextField("銘柄コード (例: 7203)", text: $code)
                    .focused($isFocused)
                    .keyboardType(.numbersAndPunctuation)
            }
            
            Section(header: Text("日付選択(年は適当でOK)")) {
                DatePicker("購入日", selection: $purchaseDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                DatePicker("売却日", selection: $saleDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
            }
            
            if let yuutai = yuutai {
                Section(header: Text("優待内容:")) {
                    Text(yuutai)
                        .font(.footnote)
                }
            }
            
            if !errorText.isEmpty {
                Text(errorText)
                    .foregroundColor(.red)
            } else {
                Section {
                    List {
                        ForEach(stockChartPairData) { pairData in
                            HStack {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 10) {
                                        Text(pairData.purchaseDateString)
                                        Text("~")
                                        Text(pairData.saleDateString)
                                    }
                                    .font(.subheadline)
                                    
                                    HStack(spacing: 4) {
                                        if let purchasePrice = pairData.purchase?.adjclose,
                                           let max = pairData.highestPrice,
                                           let min = pairData.lowestPrice
                                        {
                                            
                                            let maxParcent = ((max - purchasePrice) /  purchasePrice) * 100
                                            let minParcent = ((min - purchasePrice) /  purchasePrice) * 100
                                            Text("max: ") +
                                            Text(String(format: "%.1f", maxParcent))
                                                .foregroundColor(maxParcent >= 0 ? .red : .blue)
                                            
                                            Text("min: ") +
                                            Text(String(format: "%.1f", minParcent))
                                                .foregroundColor(minParcent >= 0 ? .red : .blue)
                                        }
                                    }
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(pairData.valueChangeParcent?.description ?? "❌")%")
                                    .foregroundColor(pairData.valueChangeParcent ?? 0 >= 0 ? .red : .blue)
                                    .font(.title2)
                            }
                        }
                    }
                } header: {
                    Text("勝率: \(YuutaiUtil.riseRateString(for: stockChartPairData))")
                }
            }
        }
        .onAppear {
            if !code.isEmpty && !hasAppeared {
                Task {
                    await fetchStockResult()
                }
            }
            hasAppeared = true
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                
                Button(action: {
                    Task {
                        isFocused = false
                        await fetchStockResult()
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("データ取得")
                    }
                }
                .disabled(code.isEmpty)
            }
        }
        .navigationTitle(stockChartPairData.isEmpty ? .constant("") : $code)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func fetchStockResult() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd" // フォーマットを指定（年/月/日）
        let start = dateFormatter.date(from: "2000/1/3")!
        errorText = ""
        stockChartPairData = []
        let result =  await YuutaiUtil.fetchStockPrice(code: code, startDate: start, endDate: Date(), purchaseDay: purchaseDate, saleDay: saleDate)
        switch result {
        case .success(let pairs):
            stockChartPairData = pairs
        case .failure(_):
            errorText = "株価データを取得できませんでした\n銘柄コードが間違っている可能性があります"
        }
        
    }
}

#Preview {
    YuutaiAnticipationView(code: .constant(""), purchaseDate: .constant(Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()), saleDate: .constant(Date()))
}
