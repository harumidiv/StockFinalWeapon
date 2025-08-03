//
//  YuutaiMonthWinningRateListScreen.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/13.
//

import SwiftUI
import SwiftSoup
import SwiftYFinance

struct TanosiiYuutaiInfo {
    let name: String
    let code: String
    let creditType: String?
}

struct StockWinningRate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let code: String
    let creditType: String?
    let stockChartData: [StockChartData]
    
    let winningRate: Float
    let totalCount: Int
    
    init(yuutaiInfo: TanosiiYuutaiInfo, stockChartData: [StockChartData], winningRate: Float, totalCount: Int) {
        self.name = yuutaiInfo.name
        self.code = yuutaiInfo.code
        self.creditType = yuutaiInfo.creditType
        self.stockChartData = stockChartData
        self.winningRate = winningRate
        self.totalCount = totalCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(code)
        hasher.combine(creditType)
    }
    
    static func == (lhs: StockWinningRate, rhs: StockWinningRate) -> Bool {
        return lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.code == rhs.code &&
        lhs.creditType == rhs.creditType
    }
}

struct YuutaiMonthWinningRateListScreen: View {
    // 特定月の銘柄リスト
    @State private var tanosiiYuutaiInfo: [TanosiiYuutaiInfo] = []
    
    @State private var selectedStock: StockWinningRate? = nil
    @State private var stockDisplayWinningRate: [StockWinningRate] = []
    @State private var isLoading: Bool = true
    
    private let baseURL = "https://www.kabuyutai.com/yutai/"
    @Binding var purchaseDate: Date
    @Binding var saleDate: Date
    let month: SelectedMonth
    
    var verificationRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let start = formatter.string(from: purchaseDate)
        let end = formatter.string(from: saleDate)
        return "\(month.ja)権利: \(start) 〜 \(end)"
    }
    
    var body: some View {
        VStack {
            HStack {
                let count = tanosiiYuutaiInfo.count == 0 ? "--" : tanosiiYuutaiInfo.count.description
                Text("\(month.ja)優待  対象銘柄数: \(count)")
                Spacer()
            }
            .padding(.horizontal)
            
            VStack {
                DatePicker("購入日", selection: $purchaseDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .disabled(isLoading)
                DatePicker("売却日", selection: $saleDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .disabled(isLoading)
            }
            .padding(.horizontal)
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(stockDisplayWinningRate) { info in
                    NavigationLink(value: info) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(info.name).lineLimit(1)
                                Text(info.code)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                if let creditType = info.creditType {
                                    Text(creditType)
                                }
                                Text("検証回数: \(info.totalCount)回")
                            }
                            
                            Text(String(format: "%.1f%%", info.winningRate))
                                .foregroundColor(info.winningRate >= 50 ? .red : .blue)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button (action: {
                    Task {
                        isLoading = true
                        var newData: [StockWinningRate] = []

                        for item in stockDisplayWinningRate {
                            let (winningRate, trialCount) = await calculateWinnigRate(chartData: item.stockChartData)
                            let result = StockWinningRate(
                                yuutaiInfo: .init(name: item.name, code: item.code, creditType: item.creditType),
                                stockChartData: item.stockChartData,
                                winningRate: winningRate,
                                totalCount: trialCount
                            )
                            newData.append(result)
                        }
                        stockDisplayWinningRate = newData.sorted {
                            $0.winningRate > $1.winningRate
                        }
                        isLoading = false
                    }
                    
                }, label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                })
                .disabled(isLoading)
            }
        }
        .navigationDestination(for: StockWinningRate.self) { info in
            YuutaiAnticipationView(
                code: .constant(info.code),
                purchaseDate: $purchaseDate,
                saleDate: $saleDate
            )
        }
        .navigationTitle(verificationRange)
        .task {
            // 個別の検証から戻った時に通信が走ってしまうので弾く
            if stockDisplayWinningRate.isEmpty {
                isLoading = true
                tanosiiYuutaiInfo = await fetchStockInfo()
                
                let infoList = await fetchAllStockInfo(stockInfo: tanosiiYuutaiInfo)
                stockDisplayWinningRate = infoList.sorted {
                    $0.winningRate > $1.winningRate
                }
                isLoading = false
            }
        }
    }
}

// 銘柄の購入日から売却日までの勝率を取得
private extension YuutaiMonthWinningRateListScreen {
    func fetchAllStockInfo(stockInfo: [TanosiiYuutaiInfo]) async -> [StockWinningRate] {
        await withTaskGroup(of: StockWinningRate?.self, returning: [StockWinningRate].self) { group in
            let start = Date()
            for item in stockInfo {
                group.addTask {
                    if let winningRate = await fetchWinningRateAndTrialCount(for: item.code) {
                        return await StockWinningRate(yuutaiInfo: item, stockChartData: winningRate.0, winningRate: winningRate.1, totalCount: winningRate.2)
                    } else {
                        return nil
                    }
                }
            }
            
            var results = [StockWinningRate]()
            for await maybeInfo in group {
                if let info = maybeInfo {
                    results.append(info)
                }
            }
            let end = Date()
            let timeInterval = end.timeIntervalSince(start)
            print("処理時間: \(timeInterval)秒")
            
            return results
        }
    }
    
    func fetchWinningRateAndTrialCount(for code: String) async -> ([StockChartData], Float, Int)? {
        let result = await YuutaiUtil.fetchStockData(code: code)
        switch result {
        case .success(let stockChartData):
            let winningRateAndTrialCount = await calculateWinnigRate(chartData: stockChartData)
            return (stockChartData, winningRateAndTrialCount.0, winningRateAndTrialCount.1)
            
        case .failure(_):
            return nil
        }
    }
    
    func calculateWinnigRate(chartData: [StockChartData]) async -> (Float, Int) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let start = dateFormatter.date(from: "2015/1/3")! // TODO: 外から入れられた方が良いかも！
        let verificationPeriod = chartData.filter {
            if let date = $0.date {
                return date > start
            }
            return false
        }
        
        let pairs = await YuutaiUtil.fetchStockPrice(stockChartData: verificationPeriod, purchaseDay: purchaseDate, saleDay: saleDate)
        return (YuutaiUtil.riseRateString(for: pairs), YuutaiUtil.trialCount(for: pairs))
    }
}

// 楽しい配当優待生活から指定月の銘柄コード一覧を取得
private extension YuutaiMonthWinningRateListScreen {
    func fetchStockInfo() async -> [TanosiiYuutaiInfo] {
        var page = 1
        var stockInfo: [TanosiiYuutaiInfo] = []
        
        while true {
            let urlString: String
            if page == 1 {
                urlString = baseURL + month.en + ".html"
            } else {
                urlString = baseURL + month.en + "\(page).html"
            }
            
            do {
                guard let html = await URL(string: urlString)?.fetchHtml() else {
                    break
                }
                
                // 👇 404系エラーページ判定
                if html.contains("お探しのページが見つかりませんでした") {
                    break
                }
                
                let info = try parseStockList(from: html)
                stockInfo += info
                
                page += 1
            } catch {
                print("⚠️ パースエラー: \(error.localizedDescription)")
                break
            }
        }
        return stockInfo
    }
    
    func parseStockList(from html: String) throws -> [TanosiiYuutaiInfo] {
        var result: [TanosiiYuutaiInfo] = []
        let pattern = "[（(]([A-Za-z0-9]{4})[）)]"
        let regex = try NSRegularExpression(pattern: pattern)
        
        do {
            let doc = try SwiftSoup.parse(html)
            let containers = try doc.select("div.table_tr_inner")
            
            for container in containers {
                let infoDiv = try container.select("div.table_tr_info").first()
                
                guard let firstP = try infoDiv?.select("p").first(),
                      let nameLink = try firstP.select("a.kigyoumei").first()
                else { continue }
                
                let name = try nameLink.text()
                let fullText = try firstP.text()
                
                let code: String
                let range = NSRange(fullText.startIndex..., in: fullText)

                if let match = regex.firstMatch(in: fullText, range: range),
                   let codeRange = Range(match.range(at: 1), in: fullText) {
                    code = String(fullText[codeRange])
                } else {
                    continue
                }
                
                // 信用貸借区分の取得
                var credit: String? = nil
                if let taishakuP = try infoDiv?.select("p.taishaku").first(),
                   let bTag = try taishakuP.select("b").first() {
                    credit = try bTag.text()
                }
                
                result.append(TanosiiYuutaiInfo(name: name, code: code, creditType: credit))
            }
        } catch {
            print("エラー: \(error)")
        }
        
        return result
    }
}


#Preview {
    YuutaiMonthWinningRateListScreen(purchaseDate: .constant(.now), saleDate: .constant(.now), month: .init(ja: "1月", en: "january"))
}

