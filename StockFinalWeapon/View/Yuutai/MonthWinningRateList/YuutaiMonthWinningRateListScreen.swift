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

struct TanosiiYuutaiInfo: Codable {
    let name: String
    let code: String
    let creditType: String?
}

@Model
final class MyStockChartData {
    var date: Date?
    var volume: Int?
    var open: Float?
    var close: Float?
    var adjclose: Float?
    var low: Float?
    var high: Float?
    
    init(stockChartData: StockChartData) {
        date = stockChartData.date
        volume = stockChartData.volume
        open = stockChartData.open
        close = stockChartData.close
        adjclose = stockChartData.adjclose
        low = stockChartData.low
        high = stockChartData.high
    }
}

@Model
final class StockWinningRate: Identifiable, Hashable {
    var month: YuutaiMonth
    var name: String
    var code: String
    var creditType: String?
    var stockChartData: [MyStockChartData]
    
    var winningRate: Float
    var totalCount: Int
    
    init(month: YuutaiMonth, yuutaiInfo: TanosiiYuutaiInfo, stockChartData: [MyStockChartData], winningRate: Float, totalCount: Int) {
        self.month = month
        self.name = yuutaiInfo.name
        self.code = yuutaiInfo.code
        self.creditType = yuutaiInfo.creditType
        self.stockChartData = stockChartData
        self.winningRate = winningRate
        self.totalCount = totalCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(month)
        hasher.combine(name)
        hasher.combine(code)
        hasher.combine(creditType)
    }
    
    static func == (lhs: StockWinningRate, rhs: StockWinningRate) -> Bool {
        return lhs.month == rhs.month &&
        lhs.name == rhs.name &&
        lhs.code == rhs.code &&
        lhs.creditType == rhs.creditType
    }
}

struct YuutaiMonthWinningRateListScreen: View {
    // 特定月の銘柄リスト
    @State private var tanosiiYuutaiInfo: [TanosiiYuutaiInfo] = []
    
    @Environment(\.modelContext) private var context
    
//    @Query(filter: #Predicate<StockWinningRate> { $0.month == .january },
//           sort: [SortDescriptor(\.winningRate, order: .reverse)])
//    private var stockDisplayWinningRate: [StockWinningRate]
    @State private var stockDisplayWinningRate: [StockWinningRate] = []
    
    @State private var selectedStock: StockWinningRate? = nil
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
                        stockDisplayWinningRate = await fetchChartData(tanosiiYuutaiInfo: tanosiiYuutaiInfo).sorted {
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
                
                tanosiiYuutaiInfo = await getYuutaiCodeList()
                
                stockDisplayWinningRate = await fetchChartData(tanosiiYuutaiInfo: tanosiiYuutaiInfo).sorted {
                    $0.winningRate > $1.winningRate
                }
                isLoading = false
            }
        }
    }
    
    @MainActor
    private func fetchChartData(tanosiiYuutaiInfo: [TanosiiYuutaiInfo]) async -> [StockWinningRate] {
        let descriptor = FetchDescriptor<StockWinningRate>(
            sortBy: [SortDescriptor(\.winningRate, order: .reverse)]
        )

        let allData = try? context.fetch(descriptor)
        let cacheData = allData?.filter { $0.month == month }

        if let cacheData, !cacheData.isEmpty {
            // 新しい日付でデータを更新
            var newWinningData: [StockWinningRate] = []
            for item in cacheData {
                let (winningRate, trialCount) = await calculateWinnigRate(chartData: item.stockChartData)
                let result = StockWinningRate(
                    month: month, yuutaiInfo: .init(name: item.name, code: item.code, creditType: item.creditType),
                    stockChartData: item.stockChartData,
                    winningRate: winningRate,
                    totalCount: trialCount
                )
                newWinningData.append(result)
            }

            return newWinningData
        }

        let newData = await fetchAllStockInfo(stockInfo: tanosiiYuutaiInfo)
        newData.forEach { context.insert($0) }

        return newData
    }
    
    private func getYuutaiCodeList() async -> [TanosiiYuutaiInfo] {
        switch month {
        case .january:
            if let cache = UserStore.january {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.january = infoData
                return infoData
            }

        case .february:
            if let cache = UserStore.february {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.february = infoData
                return infoData
            }
            
        case .march:
            if let cache = UserStore.march {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.march = infoData
                return infoData
            }
            
        case .april:
            if let cache = UserStore.april {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.april = infoData
                return infoData
            }
            
        case .may:
            if let cache = UserStore.may {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.may = infoData
                return infoData
            }
            
        case .june:
            if let cache = UserStore.june {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.june = infoData
                return infoData
            }
            
        case .july:
            if let cache = UserStore.july {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.july = infoData
                return infoData
            }
            
        case .august:
            if let cache = UserStore.august {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.august = infoData
                return infoData
            }
            
        case .september:
            if let cache = UserStore.september {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.september = infoData
                return infoData
            }
            
        case .october:
            if let cache = UserStore.october {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.october = infoData
                return infoData
            }
            
        case .november:
            if let cache = UserStore.november {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.november = infoData
                return infoData
            }
            
        case .december:
            if let cache = UserStore.december {
                return cache
            } else {
                let infoData = await fetchStockInfo()
                UserStore.december = infoData
                return infoData
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
                        return await StockWinningRate(month: month, yuutaiInfo: item, stockChartData: winningRate.0, winningRate: winningRate.1, totalCount: winningRate.2)
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
    
    func fetchWinningRateAndTrialCount(for code: String) async -> ([MyStockChartData], Float, Int)? {
        let result = await YuutaiUtil.fetchStockData(code: code)
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

