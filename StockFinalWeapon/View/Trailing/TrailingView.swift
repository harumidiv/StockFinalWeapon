//
//  Trailing.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//

import SwiftUI
import SwiftYFinance

enum Market: String, CaseIterable, Identifiable {
    case tokyo = "東証"
    case nagoya = "名証"
    case sapporo = "札証"
    case hukuoka = "福証"
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
    
    var color: Color {
        switch self {
        case .tokyo:
            return .red
        case .nagoya:
            return .yellow
        case .sapporo:
            return .blue
        case .hukuoka:
            return .green
        case .none:
            return .gray
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

struct StockCodeTag: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let market: Market
    let chartData: [StockChartData]
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        hasher.combine(code)
        hasher.combine(market)
    }

    static func == (lhs: StockCodeTag, rhs: StockCodeTag) -> Bool {
        return lhs.id == rhs.id &&
               lhs.code == rhs.code &&
               lhs.market == rhs.market
    }
}


struct TrailingView: View {
    // TODO: 入力できるようにする
    // TODO: 入力したものをTabで保存できるようにする
    @State private var codeList: [String] = [
        "2058", "8046", "6797", "5906", "3320", "5753", "8040", "6964"
    ]
    @State private var stockCodeTags: [StockCodeTag] = []
    
    @State private var selectedMarket: Market = .tokyo
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    let priceParcent:[Int] = ([Int])(-99...99)
    
    @State private var lossCut: Int = 7
    @State private var profitFixed: Int = 7
    @State private var stockList: [Stock] = []
    @FocusState private var isFocused: Bool
    @State private var code: String = ""
    @State private var market: Market = .tokyo
    
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
                        Task {
                            codeList.forEach {
                                fetchStockValue(code: $0)
                            }
                        }
                        
                    }, label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("検証")
                        }
                    })
                    .disabled(stockCodeTags.isEmpty)
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
            }
            
            Section(header: Text("値幅")) {
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
            
            Section(header: Text("銘柄入力")) {
                HStack {
                    TextField("銘柄コード (例: 7203)", text: $code)
                        .focused($isFocused)
                        .keyboardType(.numbersAndPunctuation)
                    Picker("", selection: $market) {
                        ForEach(Market.allCases){ market in
                            Text(market.rawValue)
                        }
                    }
                    .frame(width: 80)
                    
                    Button (action: {
                        Task {
                            do {
                                isFocused = false
                                isLoading = true
                                let result = try await fetchStockValue(code: code, market: market)
                                print("取得成功: \(result)")
                                stockCodeTags.append(result)
                                
                                // 初期化
                                code = ""
                                market = .tokyo
                                isLoading = false
                            } catch {
                                isLoading = false
                                // TODO: エラーがわかるようにtoastなどを出す？
                                print("エラー: \(error)")
                            }
                        }
                        
                    }, label: {
                        Label("追加", systemImage: "plus")
                            .foregroundColor(.white)
                    })
                    .buttonStyle(.borderedProminent)
                    .disabled(code.isEmpty)
                }
                
                if stockCodeTags.isEmpty {
                    Text("検証を行う銘柄を入力してください")
                        .foregroundColor(.red)
                } else {
                    ChipsView(tags: stockCodeTags) { tag in
                        ChipView(stockCodeTag: tag)
                    }
                }
               
            }
            
            if !stockList.isEmpty {
                Section(header: Text("結果")) {
                    
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
}

extension TrailingView {
    func fetchStockValue(code: String, market: Market) async throws -> StockCodeTag {
        try await withCheckedThrowingContinuation { continuation in
            SwiftYFinance.chartDataBy(
                identifier: code + market.symbol,
                start: startDate,
                end: endDate
            ) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data, let _ = data.first?.open else {
                    continuation.resume(throwing: NSError(domain: "No open price", code: 0))
                    return
                }
                
                continuation.resume(returning: StockCodeTag(code: code, market: market, chartData: data))
            }
        }
    }
    
    // TODO: あとで消す
    func fetchStockValue(code: String, market: Market = .tokyo) {
        SwiftYFinance.chartDataBy(
            identifier: code + market.symbol,
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
