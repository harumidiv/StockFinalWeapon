//
//  Trailing.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//

import SwiftUI
import SwiftYFinance

enum Market: String, CaseIterable, Identifiable {
    case tokyo = "東京証券取引所"
    case nagoya = "名古屋証券取引所"
    case sapporo = "札幌証券取引所"
    case hukuoka = "福岡証券取引所"
    case none = "海外"
    
    var id: Self { self }
    
    var symbol: String {
        switch self {
        case .tokyo:
            return ".T"
        case .nagoya:
            return ".N"
        case .sapporo:
            return ".S"
        case .hukuoka:
            return ".F"
        case .none:
            return ""
        }
    }
}

enum WinOrLose: String {
    case win = "勝ち"
    case lose = "負け"
    case unsettled = "未定"
    
    var image: String {
        switch self {
        case .win:
            return "win"
        case .lose:
            return "lose"
        case .unsettled:
            return "draw"
        }
    }
}

struct Stock: Identifiable {
    let id = UUID()
    let code: String
    let winOrLose: WinOrLose
}

struct TrailingView: View {
    // TODO: 入力できるようにする
    // TODO: 入力したものをTabで保存できるようにする
    @State private var codeList: [String] = [
        "2058", "8046", "6797", "5906", "3320", "5753", "8040", "6964"
    ]
    @State private var selectedMarket: Market = .tokyo
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    let priceParcent:[Int] = ([Int])(-99...99)
    
    @State private var lossCut: Int = 7
    @State private var profitFixed: Int = 7
    @State private var stockList: [Stock] = []
    
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView()
                } else {
                    stableView()
                }
            }
            .navigationTitle("トレイリング検証")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button (action: {
                        isLoading = true
                        stockList = []
                        codeList.forEach {
                            fetchStockValue(code: $0)
                        }
                        
                    }, label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("検証")
                        }
                    })
                }
            }
        }
    }
    
    private func loadingView() -> some View {
        ProgressView()
            .progressViewStyle(.circular)
            .padding()
            .tint(Color.white)
            .background(Color.gray)
            .cornerRadius(8)
            .scaleEffect(1.2)
            .zIndex(100)
    }
    
    private func stableView() -> some View {
        Form {
            Section(header: Text("検証項目")) {
                DatePicker(
                    "開始日",
                    selection: $startDate,
                    displayedComponents: [.date]
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))
                
                DatePicker(
                    "終了日",
                    selection: $endDate,
                    displayedComponents: [.date]
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))
                
                Picker("損切り", selection: $lossCut) {
                    ForEach(1..<100){ value in
                        Text("- \(value)")
                            .tag(value)
                    }
                }
                Picker("利確", selection: $profitFixed) {
                    ForEach(1..<100){ value in
                        Text("\(value)")
                            .tag(value)
                    }
                }
            }
            
            //            if let victoryOrDefeat = victoryOrDefeat {
            //
            //                Image(victoryOrDefeat.image)
            //                Text(victoryOrDefeat.rawValue)
            //            }
            
            if !stockList.isEmpty {
                
                let winCount = stockList.filter { $0.winOrLose == .win }.count
                let loseCount:Double = Double(stockList.filter { $0.winOrLose == .lose }.count)
                let drawCount = stockList.filter { $0.winOrLose == .unsettled }.count
                
                Text("勝ち: \(winCount), 負け: \(Int(loseCount)), 未定: \(drawCount), 負け割合: \(String(format: "%.1f", loseCount/Double(stockList.count)))")
                List {
                    ForEach(stockList) { stock in
                        HStack {
                            Text(stock.code)
                            Image(stock.winOrLose.image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                        }
                    }
                }
            }
        }
    }
}

extension TrailingView {
    func fetchStockValue(code: String) {
        SwiftYFinance.chartDataBy(
            identifier: code + selectedMarket.symbol,
            start: startDate,
            end: endDate){
                data, error in
                
                if error != nil {
                    print("エラー")
                    return
                }
                
                // 初日の始まり値で購入する想定
                guard let data = data, let startOpenPrice = data[0].open else {
                    return
                }
                
                var victoryOrDefeat: WinOrLose?
                
                data.forEach { value in
                    guard let high = value.high, let low = value.low, victoryOrDefeat == nil else {
                        return
                    }
                    
                    let highPriceDifference = high - startOpenPrice
                    let highPercent = highPriceDifference / startOpenPrice * 100
                    // 高値が始まり値より高い + 高値が利確値よりも高い
                    if high >= startOpenPrice && highPercent > Float(profitFixed) {
                        victoryOrDefeat = .win
                    }
                    
                    let lowPriceDifference = low - startOpenPrice
                    let lowParcent = lowPriceDifference / startOpenPrice * 100
                    // 安値が始まり値よりも低い + 安値が損切り値よりも低い
                    if low <= startOpenPrice && lowParcent < Float(-lossCut) {
                        victoryOrDefeat = .lose
                    }
                    
                    print("code: \(code), high: \(high), low: \(low), highPercent: \(highPercent), lowParcent: \(lowParcent)")
                }
                
                if victoryOrDefeat == nil {
                    victoryOrDefeat = .unsettled
                }
                
                stockList.append(.init(code: code, winOrLose: victoryOrDefeat!))
                isLoading = false
            }
        
    }
}

#Preview {
    TrailingView()
}
