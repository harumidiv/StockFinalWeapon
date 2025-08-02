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
    case error = "エラー"
    
    var image: String {
        switch self {
        case .win:
            return "win"
        case .lose:
            return "lose"
        case .unsettled:
            return "draw"
        case .error:
            return "error"
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
    
    func winOrLose(start: Date, end: Date, profitFixed: Int, lossCut: Int) -> WinOrLose {
        let rangeData = chartData.filter { chart in
            if let date = chart.date {
                return date >= start && date <= end
            } else {
                return false
            }
        }
        
        guard let startPrice = rangeData.first?.open else {
            return .error
        }
        
        var winOrLose: WinOrLose?
        
        rangeData.forEach { value in
            guard let high = value.high, let low = value.low, winOrLose == nil else {
                return
            }
            
            let highPriceDifference = high - startPrice
            let highPercent = highPriceDifference / startPrice * 100
            // 高値が始まり値より高い + 高値が利確値よりも高い
            if high >= startPrice && highPercent > Float(profitFixed) {
                winOrLose = .win
            }
            
            let lowPriceDifference = low - startPrice
            let lowParcent = lowPriceDifference / startPrice * 100
            // 安値が始まり値よりも低い + 安値が損切り値よりも低い
            if low <= startPrice && lowParcent < Float(-lossCut) {
                winOrLose = .lose
            }
            
            print("code: \(code), high: \(high), low: \(low), highPercent: \(highPercent), lowParcent: \(lowParcent)")
        }
        return winOrLose ?? .unsettled
    }
    
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
    @State private var stockCodeTags: [StockCodeTag] = []
    @State private var selectedMarket: Market = .tokyo
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var lossCut: Int = 7
    @State private var profitFixed: Int = 7

    @FocusState private var isFocused: Bool
    @State private var code: String = ""
    @State private var market: Market = .tokyo
    
    @State private var isLoading: Bool = false
    @State private var isPresenting = false
    
    private let priceParcent:[Int] = ([Int])(-99...99)
    
    var body: some View {
        NavigationStack {
            ZStack {
                stableView()
                if isLoading {
                    loadingView()
                }
            }
            .navigationTitle("トレイリング検証")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button (action: {
                        isPresenting = true
                        
                    }, label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("検証")
                        }
                    })
                    .disabled(stockCodeTags.isEmpty)
                }
            }
            .sheet(isPresented: $isPresenting) {
                TrailingResultView(
                    stockList: $stockCodeTags,
                    startDate: $startDate,
                    endDate: $endDate,
                    lossCut: $lossCut,
                    profitFixed: $profitFixed
                )
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
                    VStack {
                        Picker("", selection: $market) {
                            ForEach(Market.allCases){ market in
                                Text(market.rawValue)
                            }
                        }
                        .pickerStyle(.palette)
                        
                        TextField("銘柄コード (例: 7203)", text: $code)
                            .focused($isFocused)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    
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
        }
    }
}

extension TrailingView {
    func fetchStockValue(code: String, market: Market) async throws -> StockCodeTag {
        try await withCheckedThrowingContinuation { continuation in
            // 詳細画面で再利用できるように古めの情報から保持しておく
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            let start = dateFormatter.date(from: "2000/1/3")!
            
            SwiftYFinance.chartDataBy(
                identifier: code + market.symbol,
                start: start,
                end: endDate
            ) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: NSError(domain: "No open price", code: 0))
                    return
                }
                
                continuation.resume(returning: StockCodeTag(code: code, market: market, chartData: data))
            }
        }
    }
    
    // TODO: あとで消す
//    func fetchStockValue(code: String, market: Market = .tokyo) {
//        SwiftYFinance.chartDataBy(
//            identifier: code + market.symbol,
//            start: startDate,
//            end: endDate){
//                data, error in
//                
//                if error != nil {
//                    print("エラー")
//                    return
//                }
//                
//                // 初日の始まり値で購入する想定
//                guard let data = data, let startOpenPrice = data[0].open else {
//                    return
//                }
//                
//                var victoryOrDefeat: WinOrLose?
//                
//                data.forEach { value in
//                    guard let high = value.high, let low = value.low, victoryOrDefeat == nil else {
//                        return
//                    }
//                    
//                    let highPriceDifference = high - startOpenPrice
//                    let highPercent = highPriceDifference / startOpenPrice * 100
//                    // 高値が始まり値より高い + 高値が利確値よりも高い
//                    if high >= startOpenPrice && highPercent > Float(profitFixed) {
//                        victoryOrDefeat = .win
//                    }
//                    
//                    let lowPriceDifference = low - startOpenPrice
//                    let lowParcent = lowPriceDifference / startOpenPrice * 100
//                    // 安値が始まり値よりも低い + 安値が損切り値よりも低い
//                    if low <= startOpenPrice && lowParcent < Float(-lossCut) {
//                        victoryOrDefeat = .lose
//                    }
//                    
//                    print("code: \(code), high: \(high), low: \(low), highPercent: \(highPercent), lowParcent: \(lowParcent)")
//                }
//                
//                if victoryOrDefeat == nil {
//                    victoryOrDefeat = .unsettled
//                }
//                
//                stockList.append(.init(code: code, winOrLose: victoryOrDefeat!))
//                isLoading = false
//            }
//        
//    }
}

#Preview {
    TrailingView()
}
