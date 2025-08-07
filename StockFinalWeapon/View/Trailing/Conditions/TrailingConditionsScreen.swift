//
//  Trailing.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//

import SwiftUI
import SwiftYFinance

struct TrailingConditionsScreen: View {
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
    
    @State private var showAlert: Bool = false
    @State private var deleteItem: StockCodeTag?

    @State private var showErrorToast = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                stableView()
                if isLoading {
                    loadingView()
                }
                if showErrorToast {
                    VStack {
                        ToastView(message: "⚠️ 銘柄が見つかりませんでした")
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                        Spacer()
                    }
                    .padding(.bottom, 40)
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
                TrailingResultScreen(
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
                                withAnimation {
                                    showErrorToast = true
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                }
                                Task {
                                   
                                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                                    withAnimation {
                                        showErrorToast = false
                                    }
                                }
                                
                                isLoading = false
                                code = ""
                                market = .tokyo
                            }
                        }
                        
                    }, label: {
                        Label("追加", systemImage: "plus")
                            .foregroundColor(.white)
                    })
                    .buttonStyle(.borderedProminent)
                    .disabled(code.isEmpty || isLoading)
                }
                
                if stockCodeTags.isEmpty {
                    Text("検証を行う銘柄を入力してください")
                        .foregroundColor(.red)
                } else {
                    ChipsView(tags: stockCodeTags) { tag in
                        ChipView(stockCodeTag: tag)
                    } didSelect: {selection in
                        showAlert = true
                        deleteItem = selection
                    }
                    .alert("削除しますか？", isPresented: $showAlert) {
                        Button("はい", role: .destructive) {
                            if let item = deleteItem,
                               let index = stockCodeTags.firstIndex(of: item) {
                                stockCodeTags.remove(at: index)
                            }
                            deleteItem = nil
                        }
                        Button("キャンセル", role: .cancel) {
                            deleteItem = nil
                        }
                    }
                }
            }
        }
    }
}

extension TrailingConditionsScreen {
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
                
                continuation.resume(returning: StockCodeTag(code: code, market: market, chartData: data.compactMap{ MyStockChartData(stockChartData: $0)}))
            }
        }
    }
}

#Preview {
    TrailingConditionsScreen()
}
