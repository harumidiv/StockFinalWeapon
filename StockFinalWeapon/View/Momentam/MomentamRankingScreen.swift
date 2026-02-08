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
    let code: String
    let name: String
    let price: Int // 現在値
    let open: Int  // 始値
    let url: String
    
    // 騰落率（％）を計算するプロパティ
    var changePercentage: Double {
        guard open > 0 else { return 0.0 }
        return (Double(price - open) / Double(open)) * 100
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
            
            // ランキング行の取得（クラス名は適宜調整してください）
            let codes = try doc.select("ul.RankingTable__supplements__15Cu").compactMap { container in
                try container.select("li").first()?.text()
            }
            var tempStocks: [MomentumStockInfo] = []
            
            for code in codes {
                // 詳細ページから「名前・現在値・始値」を一気に取得
                if let stock = await fetchStockDetail(code: code) {
                    tempStocks.append(stock)
                    print("取得成功: \(stock.name) (\(stock.code))")
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
    
    private func fetchStockDetail(code: String) async -> MomentumStockInfo? {
        let urlString = "https://finance.yahoo.co.jp/quote/\(code).T"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let doc = try SwiftSoup.parse(html)
            
            // 1. 銘柄名の取得 (タイトル部分などから)
            // 例: <h1 class="_11S67mE8">キオクシアホールディングス(株)</h1>
            let name = try doc.select("h2.PriceBoard__name__166W").first()?.text() ?? "不明"
            
            // 2. 現在値の取得
            // 例: <span class="_3rXqN9Y8">6,120</span>
            let priceText = try doc.select("span.StyledNumber__value__3rXW").first()?.text() ?? "0"
            let price = parsePrice(priceText)
            
            // 3. 始値の取得
            let dataItems = try doc.select("dl.DataListItem__38iJ")
            var openPrice = 0
            
            for item in dataItems {
                // 2. その中の dt (見出し) に "始値" という文字が含まれているかチェック
                let term = try item.select("dt.DataListItem__term__30Fb").text()
                if term.contains("始値") {
                    // 3. 含まれていれば、そのペアになっている dd (データ) から数値を取得
                    let valueText = try item.select("dd span.DataListItem__value__11kV").text()
                    openPrice = parsePrice(valueText)
                    break // 見つかったらループ終了
                }
            }
            
            let linkCharturl = urlString + "/chart?frm=1mntly&trm=1d&scl=stndrd&styl=lne&evnts=volume&ovrIndctr=sma%2Cmma%2Clma&addIndctr=&compare="
            // 全て揃ったら構造体を返す
            return MomentumStockInfo(code: code, name: name, price: price, open: openPrice, url: linkCharturl)
            
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
                        ForEach(viewModel.stocks) {stock in
                            Link(destination: URL(string: stock.url)!) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stock.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .lineLimit(1)
                                        Text(stock.code)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(stock.price)円")
                                            .font(.system(size: 16, weight: .medium))
                                        
                                        // 騰落率のバッジ風表示
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
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .openURLInSafariView()
                            .padding()
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
