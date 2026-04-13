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

enum Sort: String, CaseIterable, Identifiable {
    case winningRate = "勝率順"
    case expectedValue = "期待値順"
    
    var id: Self { self }
}

struct YuutaiMonthWinningRateListScreen: View {
    @Environment(\.modelContext) private var context
    
    @State private var tanosiiYuutaiInfo: [TanosiiYuutaiInfo] = []
    @State private var stockDisplayWinningRate: [StockWinningRate] = []
    
    @State private var selectedStock: YuutaiSakimawariChartModel? = nil
    @State private var isLoading: Bool = true
    @State private var selectedYear: Int = 5
    @State private var selectedWinParcent: Int = 0
    
    @State private var sortCase: Sort = .winningRate
    
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
        stableView()
            .loading(isLoading)
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
                            await reloadData()
                        }
                        
                    }, label: {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                    })
                    .disabled(isLoading)
                }
            }
            .navigationDestination(for: StockWinningRate.self) { info in
                YuutaiAnticipationView(
                    code: .constant(info.yuutaiInfo.code),
                    purchaseDate: $purchaseDate,
                    saleDate: $saleDate,
                    yuutai: info.yuutaiInfo.yuutai
                )
            }
            .navigationTitle(verificationRange)
            .task {
                // 個別の検証から戻った時に通信が走ってしまうので弾く
                if stockDisplayWinningRate.isEmpty {
                    await reloadData()
                }
            }
    }
    
    private func stableView() -> some View {
        VStack {
            HStack {
                let count = tanosiiYuutaiInfo.count == 0 ? "--" : tanosiiYuutaiInfo.count.description
                Text("\(month.ja)優待 \(count)銘柄")
                
                Picker("sort順", selection: $sortCase) {
                    ForEach(Sort.allCases) { value in
                        Text(value.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: sortCase) {
                    updateList(sortedBy: sortCase)
                }
                Spacer()
                
            }
            .padding(.horizontal)
            
            HStack {
                Text("勝ち条件")
                Picker("勝利条件", selection: $selectedWinParcent) {
                    ForEach(0..<100, id: \.self) { number in
                        let value = Double(number) / 10.0
                        Text(String(format: "%.1f", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 50)
                
                Text("%")
                
                Spacer()
                
                Text("検証")
                Picker("数字を選択", selection: $selectedYear) {
                    ForEach(3...10, id: \.self) { number in
                        Text("\(number)").tag(number)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 50)
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
            
            List(stockDisplayWinningRate) { stock in
                NavigationLink(value: stock) {
                    HStack {
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text(stock.yuutaiInfo.code)
                                if let creditType = stock.yuutaiInfo.creditType {
                                    Text(creditType)
                                }
                            }
                            Text(stock.yuutaiInfo.name).lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            HStack(spacing: 0) {
                                Text("勝率: ")
                                Text(String(format: "%.1f%%", stock.winningRate))
                                    .foregroundColor(stock.winningRate >= 50 ? .red : .blue)
                            }
                            HStack(spacing: 0) {
                                Text("期待値: ")
                                Text(String(format: "%.1f%%", stock.expectedValue))
                                    .foregroundColor(stock.expectedValue >= 0 ? .red : .blue)
                            }
                            Text("試行回数: \(stock.totalCount)回")
                        }
                        
                        
                    }
                }
            }
        }
    }
    
    private func reloadData() async {
        let startTimer = Date()
        isLoading = true
        
        tanosiiYuutaiInfo = await getYuutaiCodeList()
        
        let value = await fetchStockWinningRate(tanosiiYuutaiInfo: tanosiiYuutaiInfo).sorted {
            switch sortCase {
            case .winningRate:
                 return $0.winningRate > $1.winningRate
            case .expectedValue:
                return $0.expectedValue > $1.expectedValue
            }
        }
        stockDisplayWinningRate = value
        isLoading = false
        print("処理時間: \(Date().timeIntervalSince(startTimer))秒")
    }
    
    private func updateList(sortedBy: Sort) {
        withAnimation {
            switch sortCase {
            case .winningRate:
                stockDisplayWinningRate.sort { $0.winningRate > $1.winningRate }
            case .expectedValue:
                stockDisplayWinningRate.sort { $0.expectedValue > $1.expectedValue }
            }
        }
    }
    
    private func fetchStockWinningRate(tanosiiYuutaiInfo: [TanosiiYuutaiInfo]) async -> [StockWinningRate] {
        let descriptor = FetchDescriptor<YuutaiSakimawariChartModel>()
        let allData = try? context.fetch(descriptor)
        let cacheData = allData?.filter { $0.month == month }
        
        // キャッシュがあれば即返す（無駄なfetchをしない）
        if let cacheData, !cacheData.isEmpty {
            return await processChartModels(cacheData)
        }
        
        // 新規取得
        let newData = await fetchAllStockInfo(stockInfo: tanosiiYuutaiInfo, month: month)
        
        var result: [StockWinningRate] = []
        for item in newData {
            let (expectedValue, winningRate, trialCount) = await calculateWinnigRate(chartData: item.stockChartData)
            let stockRate = StockWinningRate(chartModel: item, expectedValue: expectedValue, winningRate: winningRate, totalCount: trialCount)
            result.append(stockRate)
            
            // 重複チェック
            if !(allData?.contains(where: { $0.code == item.code && $0.month == month }) ?? false) {
                context.insert(
                    YuutaiSakimawariChartModel(
                        month: stockRate.month,
                        name: stockRate.yuutaiInfo.name,
                        code: stockRate.yuutaiInfo.code,
                        yuutai: stockRate.yuutaiInfo.yuutai,
                        creditType: stockRate.yuutaiInfo.creditType,
                        stockChartData: stockRate.stockChartData
                    )
                )
            }
        }
        
        return result
    }
    
    private func processChartModels(_ models: [YuutaiSakimawariChartModel]) async -> [StockWinningRate] {
        var result: [StockWinningRate] = []
        for model in models {
            let (expectedValue, winningRate, trialCount) = await calculateWinnigRate(chartData: model.stockChartData)
            result.append(StockWinningRate(chartModel: model, expectedValue: expectedValue, winningRate: winningRate, totalCount: trialCount))
        }
        return result
    }
    
    private func getYuutaiCodeList() async -> [TanosiiYuutaiInfo] {
        if let cache = month.tanosiiYuutaiInfo {
            return cache
        } else {
            let infoData = await fetchTanoshiiYuutaiInfo()
            UserStore.setYuutaiInfo(infoData, for: month)
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
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date()) - 11
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 3))!

        // 一度に全件並列実行するとメモリ・通信数が爆発するため、20件ずつ処理する
        let concurrencyLimit = 200
        var results = [FetchStockAllInfoModel]()

        for chunkStart in stride(from: 0, to: stockInfo.count, by: concurrencyLimit) {
            let chunk = Array(stockInfo[chunkStart..<min(chunkStart + concurrencyLimit, stockInfo.count)])

            let chunkResults = await withTaskGroup(of: FetchStockAllInfoModel?.self, returning: [FetchStockAllInfoModel].self) { group in
                for item in chunk {
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

                var batch = [FetchStockAllInfoModel]()
                for await maybeInfo in group {
                    if let info = maybeInfo {
                        batch.append(info)
                    }
                }
                return batch
            }

            results.append(contentsOf: chunkResults)
        }

        return results.compactMap { YuutaiSakimawariChartModel(month: month, yuutaiInfo: $0.info, stockChartData: $0.chartData) }
    }
    
    /// 勝率を計算
    /// - Parameter chartData: 対になるチャートデータ
    /// - Returns: (期待値, 勝率, 試行回数)
    func calculateWinnigRate(chartData: [MyStockChartData]) async -> (Float, Float, Int) {
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
        return (YuutaiUtil.expectedValue(for: pairs), YuutaiUtil.riseRateString(for: pairs, parcent: Float(selectedWinParcent)/10.0), YuutaiUtil.trialCount(for: pairs))
    }
}

// 楽しい配当優待生活から指定月の銘柄コード一覧を取得
private extension YuutaiMonthWinningRateListScreen {
    func fetchTanoshiiYuutaiInfo() async -> [TanosiiYuutaiInfo] {
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
                
                // 優待内容の取得
                var yuutai: String? = nil
                if let pTags: Elements = try infoDiv?.select("p") {
                    for p in pTags {
                        let text = try p.text()
                        if text.contains("【優待内容】") {
                            let content = text.replacingOccurrences(of: "【優待内容】", with: "")
                            yuutai = content
                        }
                    }
                }
                
                // 信用貸借区分の取得
                var credit: String? = nil
                if let taishakuP = try infoDiv?.select("p.taishaku").first(),
                   let bTag = try taishakuP.select("b").first() {
                    credit = try bTag.text()
                }
                
                result.append(TanosiiYuutaiInfo(name: name, code: code, yuutai: yuutai, creditType: credit))
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

