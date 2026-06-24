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
    let isAkaSanpei: Bool // 日足が「赤三兵」かどうか
    let isAkeNoMyojo: Bool // 日足が「明けの明星」かどうか
    let isSankuTatakikomi: Bool // 日足が「三空叩き込み」かどうか

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

            // 注意: 同じページ内に「東証（通常取引）」と「夜間PTS（時間外取引）」の
            // 2つの DataList があり、どちらにも「始値」が存在する。
            // DOM 上は通常取引の始値が先に来るため、最初に見つかった始値のみ採用する。
            // （以前は後勝ちで上書きしてしまい、PTSの始値を拾って騰落率が狂っていた）
            for item in dataItems {
                let term = try item.select("dt[class*=DataListItem__term]").text()
                let valueText = try item.select("dd span[class*=DataListItem__value]").text()

                if term.contains("始値"), openPrice == 0 {
                    openPrice = parsePrice(valueText)
                } else if term.contains("時価総額") {
                    marketCap = valueText // 例: "1,234,567百万円" や "1兆2,345億円"
                }
            }
            
            let linkCharturl = urlString + "/chart?frm=dly..."

            // 日足を1回だけ取得し、各ローソク足パターンをまとめて判定する（通信は1銘柄1回）
            let patterns = await detectCandlePatterns(code: code)

            return MomentumStockInfo(
                rank: rank,
                code: code,
                name: name,
                price: price,
                open: openPrice,
                marketCap: marketCap,
                url: linkCharturl,
                isUwabanareNarabiAka: patterns.uwabanareNarabiAka,
                isAkaSanpei: patterns.akaSanpei,
                isAkeNoMyojo: patterns.akeNoMyojo,
                isSankuTatakikomi: patterns.sankuTatakikomi
            )
            
        } catch {
            print("\(code) の詳細取得に失敗: \(error)")
            return nil
        }
    }
    
    /// 日足のOHLC（日付昇順）
    private typealias Bar = (date: Date, open: Float, high: Float, low: Float, close: Float)

    /// 各ローソク足パターンの判定結果
    private struct CandlePatternResult {
        var uwabanareNarabiAka = false
        var akaSanpei = false
        var akeNoMyojo = false
        var sankuTatakikomi = false
    }

    /// 日足チャートを1回だけ取得し、各ローソク足パターンをまとめて判定する。
    /// 全パターンが同じ日足データを使い回すため、追加の通信は発生しない。
    private func detectCandlePatterns(code: String) async -> CandlePatternResult {
        let end = Date()
        // 直近数営業日ぶんを確実に取得するため、休日を考慮して20日前から取得
        guard let start = Calendar.current.date(byAdding: .day, value: -20, to: end) else { return CandlePatternResult() }

        let result = await YahooYFinanceAPIService().fetchStockChartData(code: code, startDate: start, endDate: end)
        guard case .success(let candles) = result else { return CandlePatternResult() }

        let bars = sortedBars(from: candles)
        return CandlePatternResult(
            uwabanareNarabiAka: isUwabanareNarabiAka(bars: bars),
            akaSanpei: isAkaSanpei(bars: bars),
            akeNoMyojo: isAkeNoMyojo(bars: bars),
            sankuTatakikomi: isSankuTatakikomi(bars: bars)
        )
    }

    /// 有効なOHLCのみを日付昇順に並べる
    private func sortedBars(from candles: [MyStockChartData]) -> [Bar] {
        candles
            .compactMap { c -> Bar? in
                guard let d = c.date, let o = c.open, let h = c.high, let l = c.low, let cl = c.close else { return nil }
                return (d, o, h, l, cl)
            }
            .sorted { $0.date < $1.date }
    }

    /// 「上放れ並び赤」判定（標準）
    /// 直近3本の日足 [A, B, C] について、
    /// - A→B で窓を空けて上放れ（Bの安値 > Aの高値）
    /// - B・Cがともに陽線（赤）
    /// - Cの始値がBの始値の±2%以内（並び）
    /// - B・Cの実体の長さが概ね同程度（小さい方/大きい方 >= 0.5）
    private func isUwabanareNarabiAka(bars: [Bar]) -> Bool {
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

    /// 「赤三兵」判定（上昇転換／継続）
    /// 直近3本 [A, B, C] について、
    /// - 3本ともしっかりした陽線（実体がレンジの50%以上）
    /// - 終値が切り上がり（A.close < B.close < C.close）
    /// - 各始値が前日の実体内から始まる（だましの飛び乗りを除外）
    /// - 上ヒゲが短い（実体以下＝「先詰まり」の弱い三兵を除外）
    private func isAkaSanpei(bars: [Bar]) -> Bool {
        guard bars.count >= 3 else { return false }
        let trio = [bars[bars.count - 3], bars[bars.count - 2], bars[bars.count - 1]]

        // 3本とも陽線で、実体がしっかりある
        for bar in trio {
            guard bar.close > bar.open else { return false }
            let range = bar.high - bar.low
            guard range > 0, (bar.close - bar.open) / range >= 0.5 else { return false }
            // 上ヒゲが実体より短い
            guard bar.high - bar.close <= bar.close - bar.open else { return false }
        }

        // 終値が連続で切り上がる
        guard trio[0].close < trio[1].close, trio[1].close < trio[2].close else { return false }

        // 各始値が前日の実体内（前日始値〜前日終値）から始まる
        for i in 1..<3 {
            let prev = trio[i - 1]
            let cur = trio[i]
            guard cur.open >= prev.open, cur.open <= prev.close else { return false }
        }

        return true
    }

    /// 「明けの明星」判定（底打ち反転）
    /// 直近3本 [A(陰線), B(小さな星), C(陽線)] について、
    /// - Aは実体の大きい陰線（下降を示す）
    /// - Bは小さな実体で、Aの実体より下に窓を空けて出る（売られすぎ）
    /// - Cは陽線で、Aの実体の中心より上まで戻す
    private func isAkeNoMyojo(bars: [Bar]) -> Bool {
        guard bars.count >= 3 else { return false }
        let a = bars[bars.count - 3]
        let b = bars[bars.count - 2]
        let c = bars[bars.count - 1]

        // A: 実体の大きい陰線
        let rangeA = a.high - a.low
        guard a.close < a.open, rangeA > 0, (a.open - a.close) / rangeA >= 0.5 else { return false }

        // B: 小さな実体（星）。Aの実体に対して十分小さい
        let bodyA = a.open - a.close
        let bodyB = abs(b.close - b.open)
        guard bodyA > 0, bodyB <= bodyA * 0.5 else { return false }

        // B はAの終値より下に窓を空けて出る（実体の上端がA.close未満）
        guard max(b.open, b.close) < a.close else { return false }

        // C: 陽線で、Aの実体の中心より上まで戻す
        let midA = (a.open + a.close) / 2
        guard c.close > c.open, c.close > midA else { return false }

        return true
    }

    /// 「三空叩き込み」判定（売られすぎからの反転買いサイン）
    /// 直近4本について、隣り合う足が連続で3つ下方向の窓（前日安値 > 当日高値）を空ける。
    private func isSankuTatakikomi(bars: [Bar]) -> Bool {
        guard bars.count >= 4 else { return false }
        let quad = Array(bars.suffix(4))

        // 3連続の下方向の窓
        for i in 1..<4 {
            guard quad[i - 1].low > quad[i].high else { return false }
        }
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

    /// 酒田五法系の上昇パターンを示すバッジ
    private func patternBadge(_ title: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text(title)
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
                                            patternBadge("上放れ並び赤")
                                        }
                                        if stock.isAkaSanpei {
                                            patternBadge("赤三兵")
                                        }
                                        if stock.isAkeNoMyojo {
                                            patternBadge("明けの明星")
                                        }
                                        if stock.isSankuTatakikomi {
                                            patternBadge("三空叩き込み")
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
        // 初回のみ自動で読み込み。すでにデータがある（キャッシュ済み）場合は再読み込みしない
        .onAppear {
            guard viewModel.stocks.isEmpty, !viewModel.isLoading else { return }
            Task {
                await viewModel.fetchData()
            }
        }
    }
}

#Preview {
    MomentamRankingScreen()
}

