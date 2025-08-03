//
//  ScreeningScreen.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2024/08/07.
//

import SwiftUI
import SwiftYFinance
import SwiftSoup
import SafariServices

struct ScrapingIPOData: Identifiable {
    let id: UUID = UUID()
    
    let code: String
    let overview: String?
    let per: String?
    let percentChange: Float
    let link: String
}

struct ScreeningScreen: View {
    let priceRizeParcentage: Float
    let ipoData: [StockIPOData]
    
    @State private var isLoading: Bool = true
    @State private var progress: Float = 0
    @State private var scrapingStock: [ScrapingIPOData] = []
    
    var body: some View {
        Group {
            if isLoading {
                loadingView()
            } else {
                stableView()
            }
        }
        .task {
            isLoading = true
            scrapingStock = await fetchStockPriceRizeScreening(
                ipoData: ipoData,
                priceRizeParcentage: priceRizeParcentage
            )
            isLoading = false
            
            
            
            // CSVでの書き出し
//            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "yyyy/MM/dd" // フォーマットを指定（年/月/日）
//            let start = dateFormatter.date(from: "1949/5/16")!
//            let end = Date()
//            let stockData = await fetchStockPrice(code: "7287", startDate: start, endDate: end)
//
//            saveCSV(stockData: stockData)
        }
    }
    
    func loadingView() -> some View {
        VStack {
            ProgressView(value: progress)
            Text("進捗率: \(Int(progress*100))%")
                .monospacedDigit()
        }
        .padding()
    }
    
    @ViewBuilder
    func stableView() -> some View {
        if scrapingStock.isEmpty {
            Text("条件を満たす銘柄はありません")
            
        } else {
            VStack {
                HStack {
                    Spacer()
                    Text("\(scrapingStock.count)/\(ipoData.count)")
                        .padding()
                }
                ScrollView {
                    ForEach(scrapingStock) {stock in
                        VStack(alignment: .leading, spacing: 8) {
                            Link(destination: URL(string: stock.link)!) {
                                HStack {
                                    Text(stock.code)
                                        .font(.title)
                                    
                                    Spacer()
                                    
                                    if let per = stock.per {
                                        Text("PER: \(per)")
                                            .font(.subheadline)
                                    }
                                    
                                    Text(String(format: "%+.1f%%", stock.percentChange))
                                        .font(.headline)
                                        .foregroundColor(stock.percentChange >= 0 ? .red : .blue)
                                    
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .openURLInSafariView()
                            
                            if let overview = stock.overview {
                                Text(overview)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                    }
                }
            }
        }
    }
    
    func saveCSV(stockData: [[String]]) {
        // CSV文字列を生成
        var csvText = Constant.header.joined(separator: ",") + "\n" // ヘッダー行
        for row in stockData {
            csvText += row.joined(separator: ",") + "\n" // 各データ行
        }
        
        // ファイルの保存先パス
        let fileName = "output.csv"
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        // CSVを保存
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            print("😺CSV file saved at: \(path)")
        } catch {
            print("Failed to create file: \(error)")
        }
    }
}

// スクレイピング
extension URL {
    func fetchHtml() async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: self, delegate: nil)
            if let htmlString = String(data: data, encoding: .utf8) {
                return htmlString
            }
        } catch {
            print("❌ fetchHtml error: \(error)")
        }
        return nil
    }
}

//YahooFinanceからのデータ取得処理
extension ScreeningScreen {
    
    /// IPO銘柄に対して指定以上の上昇をしている銘柄をスクリーニングする
    /// - Parameters:
    ///   - ipoData: IPOデータの銘柄コード
    ///   - priceRizeParcentage: 上昇幅
    /// - Returns: 上昇幅を超えている銘柄のリスト
    func fetchStockPriceRizeScreening(ipoData: [StockIPOData], priceRizeParcentage: Float) async -> [ScrapingIPOData] {
        
        var stocks: [ScrapingIPOData] = .init()
        var processed = 0
        for stock in ipoData {
            do {
                // `SwiftYFinance.chartDataBy`を非同期呼び出しに変換
                let data = try await SwiftYFinanceHelper.fetchChartData(
                    identifier: "\(stock.code).T",
                    start: stock.startDate,
                    end: Date()
                )
                
                ////////////////高値確認
                /// 📝adjclose: 調整後終値,株式分割を考慮した終値
                
                // 初日終値
                let firstValue: Float = data.first?.adjclose ?? 0
                
                // 今日の終値
                let todayValue: Float = data.last?.adjclose ?? 0
                
                let parcent = (todayValue - firstValue) / firstValue * 100
                
                
                if parcent > priceRizeParcentage {
                    await stocks.append(
                        .init(
                            code: stock.code,
                            overview: try scrapingCompanyOverview(code: stock.code),
                            per: try scrapingCompanyPER(code: stock.code),
                            percentChange: parcent,
                            link: "https://finance.yahoo.co.jp/quote/\(stock.code).T"
                        )
                    )
                }
                
            } catch {
                print("エラー: \(error.localizedDescription)")
            }
            
            processed += 1
            let newProgress = Float(processed) / Float(ipoData.count)
            
            await MainActor.run {
                self.progress = newProgress
            }
        }
        
        return stocks.sorted { $0.percentChange > $1.percentChange }
    }
    
    
    /// 企業概要のスクレイピング
    /// - Parameter code: 対象企業のコード
    /// - Returns: 企業概要
    private func scrapingCompanyOverview(code: String) async throws -> String? {
        let baseUrlString = "https://finance.yahoo.co.jp/quote/\(code).T/financials"
        if let html = await URL(string: baseUrlString)?.fetchHtml(),
            let overview = try SwiftSoup.parse(html)
          .select("section.styles_FinancialSummary__section__mVJS7")
          .select("p.styles_FinancialSummary__sectionText__9ZYIc")
          .first()?
          .text() {
            return overview
            
        } else {
            return nil
        }
    }
    
    
    /// PERのスクレイピング
    /// - Parameter code:対象企業のコード
    /// - Returns: PER
    private func scrapingCompanyPER(code: String) async throws -> String? {
        let baseUrlString = "https://kabuyoho.ifis.co.jp/index.php?id=100&action=tp1&sa=report_per&bcode=\(code)"
        let selector = "table.tb_stock_range th:contains(PER (会予)) + td"
        
        if let html = await URL(string: baseUrlString)?.fetchHtml(),
           let td = try SwiftSoup.parse(html).select(selector).first() {
            let per = try td.text().trimmingCharacters(in: .whitespacesAndNewlines)
            return per
            
        } else {
            return nil
        }
    }
    
    /// IPO銘柄の情報を解析する
    /// - Parameter ipoData: iPO銘柄のデータ
    /// - Returns: 株価の情報
    func fetchStock(ipoData: [StockIPOData]) async -> [[String]] {
        var count = 0
        
        var stocks: [[String]] = .init()
        for stock in ipoData {
            do {
                // `SwiftYFinance.chartDataBy`を非同期呼び出しに変換
                let data = try await SwiftYFinanceHelper.fetchChartData(
                    identifier: "\(stock.code).T",
                    start: stock.startDate,
                    end: Date()
                )
                
                
                ////////////////高値確認
                /// 📝adjclose: 調整後終値,株式分割を考慮した終値
                
                // 初日終値
                let firstValue: Float = data.first?.adjclose ?? 0
                
                // 今日の終値
                let todayValue: Float = data.last?.adjclose ?? 0
                
                let parcent = (todayValue - firstValue) / firstValue * 100
                
                
                if parcent > 0 {
                    count += 1
                }
                
                ////////////////
                
                
                // データを加工
                let value: [[String]] = data.compactMap {
                    guard let date = $0.date,
                          let open = $0.open,
                          let close = $0.close,
                          let high = $0.high,
                          let low = $0.low else {
                        return []
                    }
                    return [date.description, open.description, close.description, high.description, low.description]
                }
                
                var resultValue = value.flatMap { $0 }
                resultValue.insert(stock.market.rawValue, at: 0)
                resultValue.insert(stock.code, at: 0)
                stocks.append(resultValue)
            } catch {
                print("エラー: \(error.localizedDescription)")
            }
        }
        
        return stocks
    }
}

#Preview {
    ScreeningScreen(priceRizeParcentage: 0, ipoData: Constant.ipo2021)
}

