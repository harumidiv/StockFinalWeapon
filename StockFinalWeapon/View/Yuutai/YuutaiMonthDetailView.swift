//
//  YuutaiMonthDetailView.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/13.
//

import SwiftUI
import SwiftSoup

struct YuutaiMonthDetailView: View {
    struct TanosiiYuutaiInfo {
        let name: String
        let code: String
        let creditType: String?
    }

    struct StockInfo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let code: String
        let creditType: String?
        let winningRate: Float
        let trialCount: Int

        init(yuutaiInfo: TanosiiYuutaiInfo, winningRate: Float, trialCount: Int) {
            self.name = yuutaiInfo.name
            self.code = yuutaiInfo.code
            self.creditType = yuutaiInfo.creditType
            self.winningRate = winningRate
            self.trialCount = trialCount
        }
    }

    @State private var selectedStock: StockInfo? = nil
    @State private var stockDisplayInfo: [StockInfo] = []
    @State private var isLoading: Bool = true
    @State private var stockCount: Int = 0

    private let baseURL = "https://www.kabuyutai.com/yutai/"
    @Binding var purchaseDate: Date
    @Binding var saleDate: Date
    let month: SelectedMonth

    var verificationRange: String {
        let start = purchaseDate.formatted(
            .dateTime
              .month(.twoDigits)
              .day(.twoDigits)
        )
        let end = saleDate.formatted(
            .dateTime
              .month(.twoDigits)
              .day(.twoDigits)
        )
        return "\(month.ja)権利: \(start) 〜 \(end)"
    }

    var body: some View {
        VStack {
            HStack {
                let count = stockCount == 0 ? "--" : stockCount.description
                Text("\(month.ja)優待, 対象銘柄数: \(count)")
                Spacer()
            }
            .padding(.horizontal)
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(stockDisplayInfo) { info in
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
                                Text("検証回数: \(info.trialCount)回")
                            }

                            Text(String(format: "%.1f%%", info.winningRate))
                                .foregroundColor(info.winningRate >= 50 ? .red : .blue)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: StockInfo.self) { info in
            YuutaiAnticipationView(
                code: .constant(info.code),
                purchaseDate: $purchaseDate,
                saleDate: $saleDate
            )
        }
        .navigationTitle(verificationRange)
        .task {
            // 個別の検証から戻った時に通信が走ってしまうので弾く
            if stockDisplayInfo.isEmpty {
                isLoading = true
                let stockInfo = await fetchStockInfo()
                stockCount = stockInfo.count
                
                let infoList = await fetchAllStockInfo(stockInfo: stockInfo)
                stockDisplayInfo = infoList.sorted {
                    $0.winningRate > $1.winningRate
                }
                isLoading = false
            }
        }
    }
    
    func fetchAllStockInfo(stockInfo: [TanosiiYuutaiInfo]) async -> [StockInfo] {
        await withTaskGroup(of: StockInfo?.self, returning: [StockInfo].self) { group in
            let start = Date()
            for item in stockInfo {
                group.addTask {
                    if let (winRate, trialCount) = await fetchWinningRate(for: item.code) {
                        return StockInfo(yuutaiInfo: item, winningRate: winRate, trialCount: trialCount)
                    } else {
                        return nil
                    }
                }
            }

            var results = [StockInfo]()
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
    
}

// 銘柄の購入日から売却日までの勝率を取得
private extension YuutaiMonthDetailView {
    func fetchWinningRate(for code: String) async -> (Float, Int)? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let start = dateFormatter.date(from: "2015/1/3")! // TODO: 外から入れられた方が良いかも？

        let result = await YuutaiUtil.fetchStockPrice(
            code: code,
            startDate: start,
            endDate: Date(),
            purchaseDay: purchaseDate,
            saleDay: saleDate
        )
        switch result {
        case .success(let pairs):
            
            return (YuutaiUtil.riseRateString(for: pairs), YuutaiUtil.trialCount(for: pairs))
        case .failure(let error):
            print("Error fetching for \(code): \(error)")
            return nil
        }
    }
}

// 楽しい配当優待生活から指定月の銘柄コード一覧を取得
private extension YuutaiMonthDetailView {
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
    YuutaiMonthDetailView(purchaseDate: .constant(.now), saleDate: .constant(.now), month: .init(ja: "1月", en: "january"))
}
