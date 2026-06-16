//
//  MomentamRankingScreen.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2026/01/30.
//

import SwiftUI
import SwiftSoup
import Combine
import SafariServices

// モデル構造体
struct MomentumStockInfo: Identifiable {
    let id = UUID()
    let rank: Int    // 売買代金ランキング順位
    let code: String
    let name: String
    let price: Int // 現在値
    let open: Int  // 始値
    let marketCap: String // 時価総額
    let url: String
    let isUwabanareNarabiAka: Bool // 日足が「上放れ並び赤」かどうか

    // 騰落率（％）を計算するプロパティ
    var changePercentage: Double {
        guard open > 0 else { return 0.0 }
        return (Double(price - open) / Double(open)) * 100
    }

    // 時価総額が1兆円未満かどうか（百万円単位の数字文字列から判定）
    var isUnderOneTrillion: Bool {
        let digits = marketCap.replacingOccurrences(of: ",", with: "").filter { $0.isNumber }
        return (Int64(digits) ?? 0) < 1_000_000
    }
}

class StockViewModel: ObservableObject {
    @Published var stocks: [MomentumStockInfo] = []
    @Published var isLoading = false
    
    // カンマ除去用ヘルパー
    private func parsePrice(_ text: String) -> Int {
        let cleanText = text.replacingOccurrences(of: ",", with: "")
            .components(separatedBy: ".")[0]
        return Int(cleanText) ?? 0
    }
    
    func fetchData() async {
        DispatchQueue.main.async { self.isLoading = true }
        
        let rankingUrl = "https://finance.yahoo.co.jp/stocks/ranking/tradingValueHigh?market=all&term=daily"
        guard let url = URL(string: rankingUrl) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return }
            let doc = try SwiftSoup.parse(html)

            // SwiftSoupでscriptタグを探し、__PRELOADED_STATE__ JSONからrank・codeを取得
            let rankCodePairs = try extractRankAndCodes(from: doc)
            var tempStocks: [MomentumStockInfo] = []

            for (rank, code) in rankCodePairs {
                if let stock = await fetchStockDetail(code: code, rank: rank) {
                    tempStocks.append(stock)
                    print("取得成功: \(stock.name) (\(stock.code)) rank:\(rank)")
                }
            }
            
            // 騰落率が高い順にソート
            let sortedStocks = tempStocks.sorted { $0.changePercentage > $1.changePercentage }
            
            DispatchQueue.main.async {
                self.stocks = sortedStocks
                self.isLoading = false
            }
        } catch {
            print("Error: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
    /// SwiftSoupでscriptタグを走査し __PRELOADED_STATE__ JSONからrank・codeを抽出
    private func extractRankAndCodes(from doc: Document) throws -> [(rank: Int, code: String)] {
        for script in try doc.select("script") {
            let content = try script.html()
            guard content.contains("__PRELOADED_STATE__"),
                  let range = content.range(of: "window.__PRELOADED_STATE__ = ") else { continue }
            var jsonStr = String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonStr.hasSuffix(";") { jsonStr = String(jsonStr.dropLast()) }
            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let results = findRankingResults(in: json) else { continue }
            return results.compactMap { item in
                let rank: Int
                if let s = item["rank"] as? String, let r = Int(s) { rank = r }
                else if let r = item["rank"] as? Int { rank = r }
                else { return nil }
                guard let code = item["stockCode"] as? String else { return nil }
                return (rank, code)
            }
        }
        return []
    }

    /// JSONを再帰探索してmainRankingList.resultsを返す
    private func findRankingResults(in json: [String: Any]) -> [[String: Any]]? {
        if let list = json["mainRankingList"] as? [String: Any],
           let results = list["results"] as? [[String: Any]] {
            return results
        }
        for (_, value) in json {
            if let nested = value as? [String: Any],
               let found = findRankingResults(in: nested) { return found }
        }
        return nil
    }

    private func fetchStockDetail(code: String, rank: Int) async -> MomentumStockInfo? {
        let urlString = "https://finance.yahoo.co.jp/quote/\(code).T"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let doc = try SwiftSoup.parse(html)
            
            // 既存の取得処理
            // Yahoo FinanceのCSSクラス名は末尾にビルドハッシュが付くため、安定部分のみで部分一致させる
            let name = try doc.select("h2[class*=BasePriceBoard__name_]").first()?.text() ?? "不明"
            let priceText = try doc.select("span[class*=StyledNumber__value]").first()?.text() ?? "0"
            let price = parsePrice(priceText)

            // --- 時価総額と始値の取得 ---
            let dataItems = try doc.select("dl[class*=_DataListItem_]")
            var openPrice = 0
            var marketCap = "---" // 初期値

            for item in dataItems {
                let term = try item.select("dt[class*=DataListItem__term]").text()
                let valueText = try item.select("dd span[class*=DataListItem__value]").text()
                
                if term.contains("始値") {
                    openPrice = parsePrice(valueText)
                } else if term.contains("時価総額") {
                    marketCap = valueText // 例: "1,234,567百万円" や "1兆2,345億円"
                }
            }
            
            let linkCharturl = urlString + "/chart?frm=dly..."

            // 日足を取得して「上放れ並び赤」かどうかを判定
            let isUwabanare = await detectUwabanareNarabiAka(code: code)

            return MomentumStockInfo(
                rank: rank,
                code: code,
                name: name,
                price: price,
                open: openPrice,
                marketCap: marketCap,
                url: linkCharturl,
                isUwabanareNarabiAka: isUwabanare
            )
            
        } catch {
            print("\(code) の詳細取得に失敗: \(error)")
            return nil
        }
    }
    
    /// 日足チャートを取得し「上放れ並び赤」パターンかどうかを判定する
    private func detectUwabanareNarabiAka(code: String) async -> Bool {
        let end = Date()
        // 直近3営業日ぶんを確実に取得するため、休日を考慮して20日前から取得
        guard let start = Calendar.current.date(byAdding: .day, value: -20, to: end) else { return false }

        let result = await YahooYFinanceAPIService().fetchStockChartData(code: code, startDate: start, endDate: end)
        switch result {
        case .success(let candles):
            return isUwabanareNarabiAka(candles: candles)
        case .failure:
            return false
        }
    }

    /// 「上放れ並び赤」判定（標準）
    /// 直近3本の日足 [A, B, C] について、
    /// - A→B で窓を空けて上放れ（Bの安値 > Aの高値）
    /// - B・Cがともに陽線（赤）
    /// - Cの始値がBの始値の±2%以内（並び）
    /// - B・Cの実体の長さが概ね同程度（小さい方/大きい方 >= 0.5）
    private func isUwabanareNarabiAka(candles: [MyStockChartData]) -> Bool {
        // 有効なOHLCのみを日付昇順に並べる
        let bars = candles
            .compactMap { c -> (date: Date, open: Float, high: Float, low: Float, close: Float)? in
                guard let d = c.date, let o = c.open, let h = c.high, let l = c.low, let cl = c.close else { return nil }
                return (d, o, h, l, cl)
            }
            .sorted { $0.date < $1.date }

        guard bars.count >= 3 else { return false }
        let a = bars[bars.count - 3]
        let b = bars[bars.count - 2]
        let c = bars[bars.count - 1]

        // 上放れ（窓空け上昇）
        guard b.low > a.high else { return false }

        // B・Cともに陽線
        guard b.close > b.open, c.close > c.open else { return false }

        // 並び：始値がほぼ同じ（±2%以内）
        guard b.open > 0 else { return false }
        guard abs(c.open - b.open) / b.open <= 0.02 else { return false }

        // 実体の長さが概ね同程度
        let bodyB = b.close - b.open
        let bodyC = c.close - c.open
        let larger = max(bodyB, bodyC)
        guard larger > 0, min(bodyB, bodyC) / larger >= 0.5 else { return false }

        return true
    }

    private func fetchOpenPrice(code: String) async -> Int? {
        let url = URL(string: "https://finance.yahoo.co.jp/quote/\(code).T")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(data: data, encoding: .utf8) ?? ""
            let doc = try SwiftSoup.parse(html)
            // 「始値」の隣の数値を抽出するセレクタ
            let openText = try doc.select("dl._3_An_R_8:has(dt:contains(始値)) dd._1D-No77_").first()?.text() ?? ""
            return parsePrice(openText)
        } catch {
            return nil
        }
    }
}

struct MomentamRankingScreen: View {
    @StateObject var viewModel = StockViewModel()
    
    var body: some View {
        NavigationView {
            ZStack { // 重ね合わせができるようにZStackを使用
                if viewModel.isLoading {
                    // 1. 読み込み中のインジケータ
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5) // サイズを少し大きく
                            .progressViewStyle(CircularProgressViewStyle())
                        
                        Text("上位銘柄の詳細データを解析中...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    
                    ScrollView {
                        ForEach(viewModel.stocks) { stock in
                            Link(destination: URL(string: stock.url)!) {
                                HStack {
                                    Text("\(stock.rank)")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 36, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stock.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .lineLimit(1)
                                        Text(stock.code)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text("時価総額: \(stock.marketCap)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(stock.isUnderOneTrillion ? .orange : .secondary)
                                        if stock.isUwabanareNarabiAka {
                                            HStack(spacing: 3) {
                                                Image(systemName: "flame.fill")
                                                Text("上放れ並び赤")
                                            }
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.red)
                                            )
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(stock.price)円")
                                            .font(.system(size: 16, weight: .medium))
                                        Text(String(format: "%+.2f%%", stock.changePercentage))
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(stock.changePercentage >= 0 ? Color.red : Color.blue)
                                            )
                                    }
                                }
                                .padding()
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .openURLInSafariView()
                        }
                    }
                }
            }
            .navigationTitle("Momentum")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.isLoading {
                        Button(action: {
                            Task { await viewModel.fetchData() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        // 画面が表示された時に自動で読み込みを開始
        .onAppear {
            Task {
                await viewModel.fetchData()
            }
        }
    }
}

#Preview {
    MomentamRankingScreen()
}

