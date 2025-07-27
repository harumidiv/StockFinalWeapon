//
//  IPODetailView.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/16.
//

import SwiftUI
import SwiftSoup

struct IPODetailView: View {
    let priceRizeParcentage: Float
    let ipoInfo: IPOInfo
    let comparison: ComparisonType
    
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
                codes: ipoInfo.stockCodes,
                priceOverParcentage: priceRizeParcentage
            )
            isLoading = false
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
                    Text("\(scrapingStock.count)/\(ipoInfo.stockCodes.count)")
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
}

//YahooFinanceからのデータ取得処理
extension IPODetailView {
    
    /// IPO銘柄に対して指定以上の上昇をしている銘柄をスクリーニングする
    /// - Parameters:
    ///   - ipoData: IPOデータの銘柄コード
    ///   - priceRizeParcentage: 上昇幅
    /// - Returns: 閾値を超えている銘柄のリスト
    func fetchStockPriceRizeScreening(codes: [String], priceOverParcentage: Float) async -> [ScrapingIPOData] {
        
        var stocks: [ScrapingIPOData] = .init()
        var processed = 0
        for code in codes {
            do {
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd"
                // IPO銘柄のデータが2011年からしかないので決め打ち
                let start = dateFormatter.date(from: "2011/1/3")!
                
                // `SwiftYFinance.chartDataBy`を非同期呼び出しに変換
                let data = try await SwiftYFinanceHelper.fetchChartData(
                    identifier: "\(code).T",
                    start: start,
                    end: Date()
                )
                
                ////////////////高値確認
                /// 📝adjclose: 調整後終値,株式分割を考慮した終値
                
                // 初日終値
                let firstValue: Float = data.first?.adjclose ?? 0
                
                // 今日の終値
                let todayValue: Float = data.last?.adjclose ?? 0
                
                let parcent = (todayValue - firstValue) / firstValue * 100
                
                switch comparison {
                case .greaterThanOrEqual where parcent > priceOverParcentage,
                     .lessThanOrEqual where parcent < priceOverParcentage:
                    await stocks.append(
                        .init(
                            code: code,
                            overview: try scrapingCompanyOverview(code: code),
                            per: try scrapingCompanyPER(code: code),
                            percentChange: parcent,
                            link: "https://finance.yahoo.co.jp/quote/\(code).T"
                        )
                    )
                default: break
                }
                
//                if parcent > priceOverParcentage {
//                    await stocks.append(
//                        .init(
//                            code: code,
//                            overview: try scrapingCompanyOverview(code: code),
//                            per: try scrapingCompanyPER(code: code),
//                            percentChange: parcent,
//                            link: "https://finance.yahoo.co.jp/quote/\(code).T"
//                        )
//                    )
//                }
                
            } catch {
                print("エラー: \(error.localizedDescription)")
            }
            
            processed += 1
            let newProgress = Float(processed) / Float(codes.count)
            
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
}

#Preview {
    IPODetailView(priceRizeParcentage: 0.0, ipoInfo: IPOInfo(year: "2024", stockCodes: ["2432", "248A"]), comparison: .greaterThanOrEqual)
}
