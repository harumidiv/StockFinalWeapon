//
//  YuutaiMonthWinningRateListScreen.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/13.
//

import SwiftUI
import SwiftSoup
import SwiftYFinance
import SwiftData

struct YuutaiMonthWinningRateListScreen: View {
    // 特定月の銘柄リスト
    @State private var tanosiiYuutaiInfo: [TanosiiYuutaiInfo] = []
    
    @Environment(\.modelContext) private var context
    
    @State private var stockDisplayWinningRate: [StockWinningRate] = []
    
    @State private var selectedStock: YuutaiSakimawariChartModel? = nil
    @State private var isLoading: Bool = true
    @State private var selectedYear: Int = 10
    
    private let baseURL = "https://www.kabuyutai.com/yutai/"
    @Binding var purchaseDate: Date
    @Binding var saleDate: Date
    let month: YuutaiMonth
    
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
                Text("\(month.ja)優待 \(count)銘柄")
                
                Spacer()
                Text("検証")
                Picker("数字を選択", selection: $selectedYear) {
                    ForEach(5...20, id: \.self) { number in
                        Text("\(number)").tag(number)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100, height: 50)
                Text("年")
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
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button (action: {
                    Task {
                        isLoading = true
                        stockDisplayWinningRate = await fetchStockWinningRate(tanosiiYuutaiInfo: tanosiiYuutaiInfo).sorted {
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
        .navigationDestination(for: YuutaiSakimawariChartModel.self) { info in
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
                let startTimer = Date()
                isLoading = true
                
                tanosiiYuutaiInfo = await getYuutaiCodeList()
                
                let value = await fetchStockWinningRate(tanosiiYuutaiInfo: tanosiiYuutaiInfo).sorted {
                    $0.winningRate > $1.winningRate
                }
                stockDisplayWinningRate = value
                isLoading = false
                print("処理時間: \(Date().timeIntervalSince(startTimer))秒")
            }
        }
    }
    
    @MainActor
    private func fetchStockWinningRate(tanosiiYuutaiInfo: [TanosiiYuutaiInfo]) async -> [StockWinningRate] {
        let descriptor = FetchDescriptor<YuutaiSakimawariChartModel>()
        
        let allData = try? context.fetch(descriptor)
        let cacheData = allData?.filter { $0.month == month }
        
        var stockWinningRate: [StockWinningRate] = []
    
        if let cacheData, !cacheData.isEmpty {
            // 新しい日付でデータを更新
            
            for item in cacheData {
                let (winningRate, trialCount) = await calculateWinnigRate(chartData: item.stockChartData)
                let result = StockWinningRate(chartModel: item, winningRate: winningRate, totalCount: trialCount)
                stockWinningRate.append(result)
            }
            
            return stockWinningRate
        }
        
        let newData = await fetchAllStockInfo(stockInfo: tanosiiYuutaiInfo, month: month)
        for item in newData {
            let (winningRate, trialCount) = await calculateWinnigRate(chartData: item.stockChartData)
            let result = StockWinningRate(chartModel: item, winningRate: winningRate, totalCount: trialCount)
            stockWinningRate.append(result)
        }
        
        // SwiftDataにデータを保存
        stockWinningRate.forEach {
            context
                .insert(
                    YuutaiSakimawariChartModel(
                        month: $0.month,
                        name: $0.name,
                        code: $0.code,
                        creditType: $0.creditType,
                        stockChartData: $0.stockChartData
                    )
                )
        }

        return stockWinningRate
    }
    
    private func getYuutaiCodeList() async -> [TanosiiYuutaiInfo] {
        if let cache = UserStore.cache(for: month) {
            return cache
        } else {
            let infoData = await fetchStockInfo()
            UserStore.setCache(infoData, for: month)
            return infoData
        }
    }
}

// 銘柄の購入日から売却日までの勝率を取得
private extension YuutaiMonthWinningRateListScreen {
    struct FetchStockAllInfoModel {
        let info: TanosiiYuutaiInfo
        let chartData: [MyStockChartData]
    }
    
    func fetchAllStockInfo(stockInfo: [TanosiiYuutaiInfo], month: YuutaiMonth) async -> [YuutaiSakimawariChartModel] {
        let value: [FetchStockAllInfoModel] = await withTaskGroup(of: FetchStockAllInfoModel?.self, returning: [FetchStockAllInfoModel].self) { group in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            // 存在しないデータはスキップされるのでかなり昔から取得
            let start = dateFormatter.date(from: "1980/1/3")!

            for item in stockInfo {
                group.addTask {
                    let result = await YahooYFinanceAPIService().fetchStockChartData(code: item.code, startDate: start, endDate: Date())
                    switch result {
                    case .success(let stockChartData):
                        return FetchStockAllInfoModel(info: item, chartData: stockChartData)
                    case .failure(_):
                        return nil
                    }
                }
            }
            
            var results = [FetchStockAllInfoModel]()
            for await maybeInfo in group {
                if let info = maybeInfo {
                    results.append(info)
                }
            }
            
            return results
        }
        
        return value.compactMap{ YuutaiSakimawariChartModel(month: month, yuutaiInfo: $0.info, stockChartData: $0.chartData) }
    }
    
    func fetchWinningRateAndTrialCount(for code: String) async -> ([MyStockChartData], Float, Int)? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        // 存在しないデータはスキップされるのでかなり昔から取得
        let start = dateFormatter.date(from: "1980/1/3")!
        
        let result = await YahooYFinanceAPIService().fetchStockChartData(code: code, startDate: start, endDate: Date())
        switch result {
        case .success(let stockChartData):
            let winningRateAndTrialCount = await calculateWinnigRate(chartData: stockChartData)
            return (stockChartData, winningRateAndTrialCount.0, winningRateAndTrialCount.1)
            
        case .failure(_):
            return nil
        }
    }
    
    func calculateWinnigRate(chartData: [MyStockChartData]) async -> (Float, Int) {
        let calendar = Calendar.current
        let today = Date()
        let tenYearsAgoYear = calendar.component(.year, from: today) - selectedYear
        guard let tenYearsAgoJan3 = calendar.date(from: DateComponents(year: tenYearsAgoYear, month: 1, day: 3)) else {
            fatalError("1/3日がないことはあり得ないので想定しないエラー")
        }
        
        let verificationPeriod = chartData.filter {
            if let date = $0.date {
                return date > tenYearsAgoJan3
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
                urlString = baseURL + month.rawValue + ".html"
            } else {
                urlString = baseURL + month.rawValue + "\(page).html"
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
    YuutaiMonthWinningRateListScreen(purchaseDate: .constant(.now), saleDate: .constant(.now), month: .january)
}

