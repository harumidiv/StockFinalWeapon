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
            let name = try doc.select("h2.PriceBoard__name__166W").first()?.text() ?? "不明"
            let priceText = try doc.select("span.StyledNumber__value__3rXW").first()?.text() ?? "0"
            let price = parsePrice(priceText)
            
            // --- 時価総額と始値の取得 ---
            let dataItems = try doc.select("dl.DataListItem__38iJ")
            var openPrice = 0
            var marketCap = "---" // 初期値
            
            for item in dataItems {
                let term = try item.select("dt.DataListItem__term__30Fb").text()
                let valueText = try item.select("dd span.DataListItem__value__11kV").text()
                
                if term.contains("始値") {
                    openPrice = parsePrice(valueText)
                } else if term.contains("時価総額") {
                    marketCap = valueText // 例: "1,234,567百万円" や "1兆2,345億円"
                }
            }
            
            let linkCharturl = urlString + "/chart?frm=dly..."
            
            return MomentumStockInfo(
                rank: rank,
                code: code,
                name: name,
                price: price,
                open: openPrice,
                marketCap: marketCap,
                url: linkCharturl
            )
            
        } catch {
            print("\(code) の詳細取得に失敗: \(error)")
            return nil
        }
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

