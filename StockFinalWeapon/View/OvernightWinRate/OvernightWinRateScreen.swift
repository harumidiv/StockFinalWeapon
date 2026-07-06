//
//  OvernightWinRateScreen.swift
//  StockFinalWeapon
//
//  銘柄コードを入力し、「終値で買って翌日の始値で売る」（オーバーナイト保有）戦略の
//  勝率を集計して表示する画面。
//

import SwiftUI
import Combine
import Charts

/// 集計期間
enum WinRatePeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1ヶ月"
    case threeMonths = "3ヶ月"
    case sixMonths = "6ヶ月"
    case oneYear = "1年"
    case allPeriod = "全期間"

    var id: Self { self }

    /// 取得に使う日数（休日を含むので余裕を持たせる）
    var days: Int {
        switch self {
        case .oneMonth: return 31
        case .threeMonths: return 93
        case .sixMonths: return 186
        case .oneYear: return 366
        case .allPeriod: return 36500 // 取得できる限り遡る（約100年）
        }
    }
}

/// 成績一覧の集計単位（年 / 月 / 週 / 日）
enum WinRateBreakdown: String, CaseIterable, Identifiable {
    case year = "年"
    case month = "月"
    case week = "週"
    case day = "日"

    var id: Self { self }

    /// バケットをまとめる & 時系列に並べるためのソート可能なキー
    func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        switch self {
        case .year:
            return String(format: "%04d", c.year ?? 0)
        case .month:
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        case .week:
            // 週はその週の開始日でまとめる（年をまたいでも一意）
            let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let s = calendar.dateComponents([.year, .month, .day], from: start)
            return String(format: "%04d-%02d-%02d", s.year ?? 0, s.month ?? 0, s.day ?? 0)
        case .day:
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
    }

    /// 画面表示用のラベル
    func label(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        switch self {
        case .year:
            return String(format: "%04d", c.year ?? 0)
        case .month:
            return String(format: "%04d/%02d", c.year ?? 0, c.month ?? 0)
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let s = calendar.dateComponents([.month, .day], from: start)
            return String(format: "%d/%d〜", s.month ?? 0, s.day ?? 0)
        case .day:
            return String(format: "%02d/%02d/%02d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
        }
    }
}

/// 検証する売買戦略
enum WinRateStrategy: String, CaseIterable, Identifiable {
    /// 当日終値で買い、翌日始値で売る（オーバーナイト保有）
    case overnight
    /// 当日始値で買い、当日終値で売る（デイトレード・日計り）
    case intraday

    var id: Self { self }

    /// 画面タイトル
    var navigationTitle: String {
        switch self {
        case .overnight: return "引in→寄out 勝率"
        case .intraday: return "寄in→引out 勝率"
        }
    }

    /// 入力フォーム上部の説明文
    var formDescription: String {
        switch self {
        case .overnight: return "当日の終値で買い、翌日の始値で売った場合（オーバーナイト保有）の勝率を集計します。"
        case .intraday: return "当日の始値で買い、当日の終値で売った場合（デイトレード）の勝率を集計します。"
        }
    }

    /// チャート凡例や成績表で使う戦略の短い名前
    var shortLabel: String {
        switch self {
        case .overnight: return "オーバーナイト"
        case .intraday: return "デイトレ"
        }
    }
}

/// 資産推移チャートの1点（初期投資額をそろえて各戦略を比較する）
struct OvernightEquityPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let overnight: Double    // オーバーナイト戦略（引け買い→翌寄り売りを毎日繰り返した）評価額・コスト前（円）
    let overnightNet: Double // 上記から 税(20.315%)・信用金利(年2.8%) を控除した実質手取り（円）
    let buyAndHold: Double   // 100株をずっと保有した場合の評価額（円）
}

/// 期間ごとのパフォーマンス（年/月/週/日で共通して使う）
struct OvernightPeriodPerformance: Identifiable {
    let id: String               // バケットのキー（"2024" / "2024-08" など。時系列にソート可能）
    let label: String            // 画面表示用ラベル
    let trades: Int              // その期間のトレード回数
    let winRate: Double          // その期間の勝率（％）
    let principal: Double        // その期間の元本（期首時点の税・金利控除後の評価額。前期間末の手取り評価額。最初は初期投資額）
    let overnightProfit: Double  // その期間のオーバーナイト戦略損益（円）
    let buyAndHoldProfit: Double // その期間の保有損益（円・100株、期首終値→期末終値）
    let overnightProfitPercent: Double  // その期間のオーバーナイト損益率（期首の評価額=元本に対する％）
    let buyAndHoldProfitPercent: Double // その期間の保有損益率（期首終値に対する％）
    let buyPrice: Float?   // 買値（日単位=1トレードのときのみ意味を持つ）
    let sellPrice: Float?  // 売値（同上）
}

/// 曜日ごとのパフォーマンス（エントリー日=買った日の曜日で集計）
struct OvernightWeekdayPerformance: Identifiable {
    var id: Int { weekday }
    let weekday: Int             // Calendar.component(.weekday) の値（1=日 … 7=土）
    let trades: Int              // その曜日のトレード回数
    let winRate: Double          // その曜日の勝率（％）
    let averageReturn: Double    // その曜日の1トレードあたり平均損益率（％）
    let averageWin: Double       // 勝ちトレードの平均利益率（％）。勝ちが無ければ0
    let averageLoss: Double      // 負けトレードの平均損失率（％・負値）。負けが無ければ0
    let worstReturn: Double      // その曜日の最大の負け（1トレードの最悪損益率・％）。負けが無ければ0

    /// ペイオフレシオ（平均利益率 ÷ 平均損失率の絶対値）。1を超えると勝ちの方が大きい。
    /// 負けが無い場合は nil（比が定義できない）
    var payoffRatio: Double? {
        guard averageLoss < 0 else { return nil }
        return averageWin / abs(averageLoss)
    }

    /// 曜日の日本語1文字表記（月・火・…）
    var shortName: String {
        switch weekday {
        case 1: return "日"
        case 2: return "月"
        case 3: return "火"
        case 4: return "水"
        case 5: return "木"
        case 6: return "金"
        case 7: return "土"
        default: return "?"
        }
    }
}

/// 集計結果
struct OvernightWinRateResult {
    let code: String
    let strategy: WinRateStrategy // 検証した売買戦略（引→翌寄 / 寄→引）
    let totalTrades: Int    // トレード回数
    let wins: Int           // 勝ち（翌日始値 > 当日終値）
    let losses: Int         // 負け（翌日始値 < 当日終値）
    let draws: Int          // 引き分け（同値）
    let winRate: Double          // 勝率（％）
    let averageReturn: Double    // 1トレードあたり平均損益率（％）
    let cumulativeReturn: Double // 期間中ずっと繰り返した場合の累積リターン（％）
    let buyAndHoldReturn: Double // 期間中ずっと保有した場合の上昇率（％）
    let equityCurve: [OvernightEquityPoint] // 資産推移（2戦略の比較用）
    let periodPerformance: [WinRateBreakdown: [OvernightPeriodPerformance]] // 年/月/週/日ごとの成績
    let weekdayPerformance: [OvernightWeekdayPerformance] // 曜日ごとの成績（エントリー日の曜日で集計）
    let isCompounding: Bool // オーバーナイト戦略を複利で計算したか（false=単利・100株固定）
    let lotSize: Int        // 複利時の売買単位（1株単位 or 100株単位）
    let startDate: Date?
    let endDate: Date?

    // 曜日を除外した期間別成績を後から再計算するための元データ
    let bars: [(date: Date, open: Float, close: Float)]
    let trades: [(buy: Float, sell: Float, buyDate: Date, sellDate: Date, sellClose: Float, daysHeld: Int)]
    let initialCapital: Double
    let shares: Double
}

extension OvernightWinRateResult {
    /// 取得したローソク足から、指定した戦略（引→翌寄 / 寄→引）の集計結果を作る。
    /// 有効データが2本未満の場合は nil を返す。
    /// - Parameters:
    ///   - strategy: .overnight=当日終値で買い翌日始値で売る / .intraday=当日始値で買い当日終値で売る
    ///   - compounding: true=複利（損益を再投資して建玉を増やす）, false=単利（100株固定）
    ///   - lotSize: 複利時の売買単位（1=1株単位, 100=100株単位）。余りは現金として持ち越す。
    ///   - principal: 指定元本（円）。nil または 0以下 のときは従来どおり「最初の終値で100株」を元本とする。
    ///                指定時は開始時にその金額で買える整数単元（100株単位・最低1単元）を建玉の基準とし、
    ///                単利の固定株数・複利の初期資金・ずっと保有の株数すべてに反映する。
    static func make(code: String, candles: [MyStockChartData], strategy: WinRateStrategy, compounding: Bool, lotSize: Int, principal: Double? = nil) -> OvernightWinRateResult? {
        // 有効な始値・終値のみを日付昇順に整理
        let bars = candles
            .compactMap { c -> (date: Date, open: Float, close: Float)? in
                guard let d = c.date, let o = c.open, let cl = c.close, o > 0, cl > 0 else { return nil }
                return (d, o, cl)
            }
            .sorted { $0.date < $1.date }

        guard bars.count >= 2 else { return nil }

        // 初期投資額（元本）を決める。
        // - 元本未指定: 従来どおり「最初の終値で100株」を元本とする
        // - 元本指定: その金額で買える整数単元（100株単位・最低1単元）を建玉の基準とし、元本=指定額
        let firstClose = bars.first!.close
        let shares: Double
        let initialCapital: Double
        if let principal, principal > 0 {
            let unitPrice = Double(firstClose) * 100 // 1単元（100株）の金額
            let units = unitPrice > 0 ? max(1.0, (principal / unitPrice).rounded(.down)) : 1.0
            shares = units * 100
            initialCapital = principal
        } else {
            shares = 100.0
            initialCapital = Double(firstClose) * shares
        }

        // 複利（全額再投資）か単利（100株固定でキャッシュに積み上げ）か
        let useCompounding = compounding
        let calendar = Calendar.current

        // 戦略ごとに1トレード（買値・売値・決済日・決済日の終値・保有日数）の列を作る。
        // - .overnight: 当日終値で買い、翌日始値で売る（決済日=翌日、翌日まで持ち越すので金利あり）
        // - .intraday : 当日始値で買い、当日終値で売る（決済日=当日、日計りなので保有日数=0=金利なし）
        let trades: [(buy: Float, sell: Float, buyDate: Date, sellDate: Date, sellClose: Float, daysHeld: Int)]
        switch strategy {
        case .overnight:
            trades = (0..<(bars.count - 1)).map { i in
                let daysHeld = max(1, calendar.dateComponents([.day], from: bars[i].date, to: bars[i + 1].date).day ?? 1)
                return (bars[i].close, bars[i + 1].open, bars[i].date, bars[i + 1].date, bars[i + 1].close, daysHeld)
            }
        case .intraday:
            trades = (0..<bars.count).map { i in
                (bars[i].open, bars[i].close, bars[i].date, bars[i].date, bars[i].close, 0)
            }
        }

        guard !trades.isEmpty else { return nil }

        // 資産推移カーブ（複利/単利・信用金利・税を反映）を作る
        let equityCurve = simulateEquityCurve(
            trades: trades,
            startDate: bars[0].date,
            initialCapital: initialCapital,
            shares: shares,
            compounding: useCompounding,
            lotSize: lotSize
        )

        // 勝敗・平均損益率・曜日別集計（曜日は買った日=エントリー日で集計）
        var wins = 0, losses = 0, draws = 0
        var returnSum = 0.0
        // winReturnSum=勝ちトレードの損益率合計 / lossReturnSum=負けトレードの損益率合計(負値) / worst=最悪の1トレード
        var weekdayStats: [Int: (trades: Int, wins: Int, returnSum: Double, lossCount: Int, winReturnSum: Double, lossReturnSum: Double, worst: Double)] = [:]
        for t in trades {
            let buy = t.buy
            let sell = t.sell
            let ret = Double(sell - buy) / Double(buy)
            returnSum += ret

            if sell > buy {
                wins += 1
            } else if sell < buy {
                losses += 1
            } else {
                draws += 1
            }

            let weekday = calendar.component(.weekday, from: t.buyDate)
            var ws = weekdayStats[weekday] ?? (trades: 0, wins: 0, returnSum: 0.0, lossCount: 0, winReturnSum: 0.0, lossReturnSum: 0.0, worst: 0.0)
            ws.trades += 1
            ws.returnSum += ret
            if sell > buy {
                ws.wins += 1
                ws.winReturnSum += ret
            } else if sell < buy {
                ws.lossCount += 1
                ws.lossReturnSum += ret
                ws.worst = min(ws.worst, ret)
            }
            weekdayStats[weekday] = ws
        }

        let total = trades.count
        let finalEquity = equityCurve.last?.overnight ?? initialCapital

        // 期間中ずっと保有した場合の上昇率（最初の終値で買い、最後の終値で売る）
        let lastClose = bars.last!.close
        let buyAndHoldReturn = Double(lastClose - firstClose) / Double(firstClose) * 100

        // 年/月/週/日ごとの成績をまとめて集計
        var periodPerformance: [WinRateBreakdown: [OvernightPeriodPerformance]] = [:]
        for breakdown in WinRateBreakdown.allCases {
            periodPerformance[breakdown] = buildPeriodPerformance(
                bars: bars,
                trades: trades,
                equityCurve: equityCurve,
                initialCapital: initialCapital,
                shares: shares,
                calendar: calendar,
                breakdown: breakdown
            )
        }

        // 曜日ごとの成績を月〜日の順（月=2 … 土=7, 日=1）で並べる
        let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
        let weekdayPerformance: [OvernightWeekdayPerformance] = weekdayOrder.compactMap { wd in
            guard let s = weekdayStats[wd], s.trades > 0 else { return nil }
            return OvernightWeekdayPerformance(
                weekday: wd,
                trades: s.trades,
                winRate: Double(s.wins) / Double(s.trades) * 100,
                averageReturn: s.returnSum / Double(s.trades) * 100,
                averageWin: s.wins > 0 ? s.winReturnSum / Double(s.wins) * 100 : 0,
                averageLoss: s.lossCount > 0 ? s.lossReturnSum / Double(s.lossCount) * 100 : 0,
                worstReturn: s.worst * 100
            )
        }

        return OvernightWinRateResult(
            code: code,
            strategy: strategy,
            totalTrades: total,
            wins: wins,
            losses: losses,
            draws: draws,
            winRate: Double(wins) / Double(total) * 100,
            averageReturn: returnSum / Double(total) * 100,
            cumulativeReturn: (finalEquity - initialCapital) / initialCapital * 100,
            buyAndHoldReturn: buyAndHoldReturn,
            equityCurve: equityCurve,
            periodPerformance: periodPerformance,
            weekdayPerformance: weekdayPerformance,
            isCompounding: useCompounding,
            lotSize: lotSize,
            startDate: bars.first?.date,
            endDate: bars.last?.date,
            bars: bars,
            trades: trades,
            initialCapital: initialCapital,
            shares: shares
        )
    }

    /// トレード列から資産推移カーブ（複利/単利・信用金利・税を反映）を作る。
    /// - 建玉株数: 複利=資金で買える整数単位ぶん / 単利=100株固定
    /// - 信用取引なので、初期資金が1単位に満たなくても最低1単位は建てる（不足分は信用＝マージン）
    /// - 手取り: 金利を引いた後、含み益にのみ課税し、損失は満額負担
    private static func simulateEquityCurve(
        trades: [(buy: Float, sell: Float, buyDate: Date, sellDate: Date, sellClose: Float, daysHeld: Int)],
        startDate: Date,
        initialCapital: Double,
        shares: Double,
        compounding: Bool,
        lotSize: Int
    ) -> [OvernightEquityPoint] {
        let taxRate = 0.20315          // 譲渡益課税 20.315%
        let annualInterestRate = 0.028 // 信用金利 年2.8%

        var overnightEquity = initialCapital  // 戦略の評価額（コスト前）
        var cumulativeInterest = 0.0          // 累積の信用金利

        // 1点目（取引前。初期投資額からスタート）
        var equityCurve: [OvernightEquityPoint] = [
            OvernightEquityPoint(date: startDate, overnight: initialCapital, overnightNet: initialCapital, buyAndHold: initialCapital)
        ]

        for t in trades {
            let buy = t.buy
            let sell = t.sell

            let heldShares: Double
            if compounding {
                let unitCost = Double(buy) * Double(lotSize)            // 1単位（lotSize株）の金額
                if overnightEquity > 0 && unitCost > 0 {
                    let lots = max(1, (overnightEquity / unitCost).rounded(.down))
                    heldShares = lots * Double(lotSize)
                } else {
                    heldShares = 0
                }
            } else {
                heldShares = shares
            }

            // 信用金利: 実際に建てた金額に対し、持ち越した日数ぶん課金（日計り=0日なので発生しない）
            let notional = heldShares * Double(buy)
            cumulativeInterest += notional * annualInterestRate * Double(t.daysHeld) / 365.0

            // 評価額の更新（複利=損益を再投資して建玉が育つ / 単利=100株固定の損益をキャッシュ加算）
            overnightEquity += heldShares * Double(sell - buy)

            let afterInterest = overnightEquity - cumulativeInterest
            let netProfit = afterInterest - initialCapital
            let overnightNet = netProfit > 0 ? initialCapital + netProfit * (1 - taxRate) : afterInterest

            let buyAndHoldEquity = Double(t.sellClose) * shares
            equityCurve.append(
                OvernightEquityPoint(date: t.sellDate, overnight: overnightEquity, overnightNet: overnightNet, buyAndHold: buyAndHoldEquity)
            )
        }
        return equityCurve
    }

    /// 曜日チェックに連動する上部サマリー（回数・勝敗・勝率・平均損益率・累積リターン）
    struct FilteredSummary {
        let totalTrades: Int
        let wins: Int
        let losses: Int
        let draws: Int
        let winRate: Double
        let averageReturn: Double
        let cumulativeReturn: Double
    }

    /// 指定した曜日（買った日の曜日）を除外したサマリーを返す。
    /// 除外なしなら事前計算済みの値をそのまま返す。
    func summary(excludingWeekdays excluded: Set<Int>) -> FilteredSummary {
        if excluded.isEmpty {
            return FilteredSummary(
                totalTrades: totalTrades, wins: wins, losses: losses, draws: draws,
                winRate: winRate, averageReturn: averageReturn, cumulativeReturn: cumulativeReturn
            )
        }
        let calendar = Calendar.current
        let filtered = trades.filter { !excluded.contains(calendar.component(.weekday, from: $0.buyDate)) }
        guard !filtered.isEmpty else {
            return FilteredSummary(totalTrades: 0, wins: 0, losses: 0, draws: 0, winRate: 0, averageReturn: 0, cumulativeReturn: 0)
        }
        var w = 0, l = 0, d = 0
        var returnSum = 0.0
        for t in filtered {
            let ret = Double(t.sell - t.buy) / Double(t.buy)
            returnSum += ret
            if t.sell > t.buy { w += 1 } else if t.sell < t.buy { l += 1 } else { d += 1 }
        }
        let equity = Self.simulateEquityCurve(
            trades: filtered,
            startDate: bars.first?.date ?? Date(),
            initialCapital: initialCapital,
            shares: shares,
            compounding: isCompounding,
            lotSize: lotSize
        )
        let finalEquity = equity.last?.overnight ?? initialCapital
        let n = filtered.count
        return FilteredSummary(
            totalTrades: n,
            wins: w, losses: l, draws: d,
            winRate: Double(w) / Double(n) * 100,
            averageReturn: returnSum / Double(n) * 100,
            cumulativeReturn: initialCapital != 0 ? (finalEquity - initialCapital) / initialCapital * 100 : 0
        )
    }

    /// 指定した曜日（買った日の曜日）を除外して、期間別成績を再計算する。
    /// 除外すると建玉サイズ（複利）や金利の推移が変わるので、資産推移から作り直す。
    func periodPerformanceList(breakdown: WinRateBreakdown, excludingWeekdays excluded: Set<Int>) -> [OvernightPeriodPerformance] {
        // 何も除外していなければ事前計算済みを返す
        if excluded.isEmpty {
            return periodPerformance[breakdown] ?? []
        }
        let calendar = Calendar.current
        let filtered = trades.filter { !excluded.contains(calendar.component(.weekday, from: $0.buyDate)) }
        let startDate = bars.first?.date ?? Date()
        let equity = Self.simulateEquityCurve(
            trades: filtered,
            startDate: startDate,
            initialCapital: initialCapital,
            shares: shares,
            compounding: isCompounding,
            lotSize: lotSize
        )
        return Self.buildPeriodPerformance(
            bars: bars,
            trades: filtered,
            equityCurve: equity,
            initialCapital: initialCapital,
            shares: shares,
            calendar: calendar,
            breakdown: breakdown
        )
    }

    /// 指定した集計単位（年/月/週/日）で成績を集計する。
    /// トレードは「買った日（エントリー日）」の属する期間に計上する（曜日別集計と基準をそろえる）。
    /// - トレード回数・勝ち・戦略損益は、そのトレードを「買った日」の期間へ
    /// - 戦略損益は資産推移カーブの差分（＝各トレードの正確な損益。複利・単利どちらにも追従）
    /// - 保有損益は各期間の「最初の終値→最後の終値」
    private static func buildPeriodPerformance(
        bars: [(date: Date, open: Float, close: Float)],
        trades: [(buy: Float, sell: Float, buyDate: Date, sellDate: Date, sellClose: Float, daysHeld: Int)],
        equityCurve: [OvernightEquityPoint],
        initialCapital: Double,
        shares: Double,
        calendar: Calendar,
        breakdown: WinRateBreakdown
    ) -> [OvernightPeriodPerformance] {
        // 期間バケットを作る（bars は日付昇順なので、初出順 = 時系列順）
        // profitSum=そのバケットのトレード損益合計 / endNet=バケット内最後のトレード後の手取り評価額
        // buyPrice/sellPrice=バケット最初の買値・最後の売値（日単位=1トレードのとき、その日の売買値になる）
        var buckets: [String: (label: String, trades: Int, wins: Int, profitSum: Double, endNet: Double?, firstClose: Float, lastClose: Float, buyPrice: Float?, sellPrice: Float?)] = [:]
        var order: [String] = []
        for bar in bars {
            let k = breakdown.key(for: bar.date, calendar: calendar)
            if var e = buckets[k] {
                e.lastClose = bar.close
                buckets[k] = e
            } else {
                buckets[k] = (label: breakdown.label(for: bar.date, calendar: calendar), trades: 0, wins: 0, profitSum: 0, endNet: nil, firstClose: bar.close, lastClose: bar.close, buyPrice: nil, sellPrice: nil)
                order.append(k)
            }
        }
        // 各トレードの損益（資産カーブの差分）を「買った日」のバケットに計上
        // equityCurve[0]=取引前, equityCurve[i+1]=トレードi決済後 なので、トレードiの損益 = 差分
        for i in 0..<trades.count {
            let t = trades[i]
            let k = breakdown.key(for: t.buyDate, calendar: calendar)
            guard var e = buckets[k] else { continue }
            let profit = equityCurve[i + 1].overnight - equityCurve[i].overnight
            e.trades += 1
            if t.sell > t.buy { e.wins += 1 }
            e.profitSum += profit
            e.endNet = equityCurve[i + 1].overnightNet
            if e.buyPrice == nil { e.buyPrice = t.buy }
            e.sellPrice = t.sell
            buckets[k] = e
        }

        var performance: [OvernightPeriodPerformance] = []
        var previousEndEquity = initialCapital     // 期首の評価額（コスト前）
        var previousEndNetEquity = initialCapital  // 期首の手取り評価額（表示用の元本）
        for k in order {
            let e = buckets[k]!
            let startEquity = previousEndEquity
            let startNetEquity = previousEndNetEquity
            let overnightProfit = e.profitSum
            previousEndEquity = startEquity + overnightProfit
            if let en = e.endNet { previousEndNetEquity = en }
            let buyAndHoldProfit = Double(e.lastClose - e.firstClose) * shares
            performance.append(
                OvernightPeriodPerformance(
                    id: k,
                    label: e.label,
                    trades: e.trades,
                    winRate: e.trades > 0 ? Double(e.wins) / Double(e.trades) * 100 : 0,
                    principal: startNetEquity,
                    overnightProfit: overnightProfit,
                    buyAndHoldProfit: buyAndHoldProfit,
                    overnightProfitPercent: startEquity != 0 ? overnightProfit / startEquity * 100 : 0,
                    buyAndHoldProfitPercent: e.firstClose != 0 ? Double(e.lastClose - e.firstClose) / Double(e.firstClose) * 100 : 0,
                    buyPrice: e.buyPrice,
                    sellPrice: e.sellPrice
                )
            )
        }
        return performance
    }
}

@MainActor
final class OvernightWinRateViewModel: ObservableObject {
    @Published var result: OvernightWinRateResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// true=複利（損益を再投資）, false=単利（100株固定）
    @Published var isCompounding = false
    /// 複利時の売買単位（1=1株単位, 100=100株単位）
    @Published var lotSize = 100
    /// 指定元本（円）。nil のときは「最初の終値で100株」を元本とする
    @Published var principal: Double?

    /// 検証する売買戦略（引→翌寄 / 寄→引）
    let strategy: WinRateStrategy

    // 取得済みのデータ。複利/単利の切り替え時に再取得せず手元で再計算するために保持する。
    private var lastCandles: [MyStockChartData] = []
    private var lastCode: String = ""

    init(strategy: WinRateStrategy = .overnight) {
        self.strategy = strategy
    }

    /// 今日から period.days 分遡って集計する
    func calculate(code: String, period: WinRatePeriod) async {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -period.days, to: end) else { return }
        await calculate(code: code, start: start, end: end)
    }

    /// 開始日〜終了日を明示的に指定して集計する
    func calculate(code: String, start: Date, end: Date) async {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard start < end else {
            errorMessage = "開始日は終了日より前の日付を指定してください。"
            result = nil
            return
        }

        isLoading = true
        errorMessage = nil
        result = nil

        let apiResult = await YahooYFinanceAPIService().fetchStockChartData(code: trimmed, startDate: start, endDate: end)

        switch apiResult {
        case .success(let candles):
            lastCandles = candles
            lastCode = trimmed
            guard let made = OvernightWinRateResult.make(code: trimmed, candles: candles, strategy: strategy, compounding: isCompounding, lotSize: lotSize, principal: principal) else {
                errorMessage = "データが不足しています。銘柄コードと期間をご確認ください。"
                isLoading = false
                return
            }
            result = made

        case .failure(let error):
            errorMessage = "取得に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 複利/単利・売買単位の切り替え時に、取得済みデータから再計算する（通信なし）
    func recompute() {
        guard !lastCandles.isEmpty else { return }
        result = OvernightWinRateResult.make(code: lastCode, candles: lastCandles, strategy: strategy, compounding: isCompounding, lotSize: lotSize, principal: principal)
    }
}

/// 期間の指定方法
enum WinRateRangeMode: String, CaseIterable, Identifiable {
    case preset = "期間プリセット"
    case custom = "日付指定"
    var id: Self { self }
}

struct OvernightWinRateScreen: View {
    let strategy: WinRateStrategy
    @StateObject private var viewModel: OvernightWinRateViewModel
    @State private var code: String = ""
    @State private var principalText: String = ""
    @State private var period: WinRatePeriod = .oneYear
    @State private var rangeMode: WinRateRangeMode = .preset
    @State private var startDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @FocusState private var isFocused: Bool

    init(strategy: WinRateStrategy = .overnight) {
        self.strategy = strategy
        _viewModel = StateObject(wrappedValue: OvernightWinRateViewModel(strategy: strategy))
    }

    /// 入力された元本テキストを円に変換する（カンマ・空白は無視。未入力/0以下は nil=100株基準）
    private var parsedPrincipal: Double? {
        let cleaned = principalText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    /// 現在のモードに応じて計算を実行
    private func runCalculation() async {
        viewModel.principal = parsedPrincipal
        switch rangeMode {
        case .preset:
            await viewModel.calculate(code: code, period: period)
        case .custom:
            await viewModel.calculate(code: code, start: startDate, end: endDate)
        }
    }

    /// 現在のモードに応じた集計期間（開始日・終了日）。ランキング一覧へ引き継ぐ。
    private var resolvedRange: (start: Date, end: Date) {
        switch rangeMode {
        case .preset:
            let end = Date()
            let start = Calendar.current.date(byAdding: .day, value: -period.days, to: end) ?? end
            return (start, end)
        case .custom:
            return (startDate, endDate)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(strategy.formDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    // 入力フォーム
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("銘柄コード (例: 7203)", text: $code)
                            .focused($isFocused)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("元本 (円・未入力なら100株)", text: $principalText)
                                .focused($isFocused)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: principalText) { _, _ in
                                    // 取得済みデータから即再計算（通信なし）。未計算なら no-op。
                                    viewModel.principal = parsedPrincipal
                                    viewModel.recompute()
                                }
                            Text("指定した元本で買える整数単元（100株単位・最低1単元）で検証します。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Picker("指定方法", selection: $rangeMode) {
                            ForEach(WinRateRangeMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch rangeMode {
                        case .preset:
                            Picker("期間", selection: $period) {
                                ForEach(WinRatePeriod.allCases) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                        case .custom:
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker("開始日", selection: $startDate, in: ...endDate, displayedComponents: .date)
                                DatePicker("終了日", selection: $endDate, in: startDate..., displayedComponents: .date)
                            }
                            .font(.system(size: 14))
                        }

                        // リターンの計算方法（取得済みデータから即再計算。通信は走らない）
                        Picker("リターン計算", selection: $viewModel.isCompounding) {
                            Text("単利（100株固定）").tag(false)
                            Text("複利").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.isCompounding) { _, _ in
                            viewModel.recompute()
                        }

                        // 複利のときだけ、再投資の売買単位を選べる（余りは現金で持ち越す）
                        if viewModel.isCompounding {
                            Picker("売買単位", selection: $viewModel.lotSize) {
                                Text("1株単位").tag(1)
                                Text("100株単位").tag(100)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: viewModel.lotSize) { _, _ in
                                viewModel.recompute()
                            }
                        }

                        Button(action: {
                            Task {
                                isFocused = false
                                await runCalculation()
                            }
                        }) {
                            Label("勝率を計算", systemImage: "chart.line.uptrend.xyaxis")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 20)
                    } else if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    } else if let result = viewModel.result {
                        OvernightWinRateResultCard(result: result)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(strategy.navigationTitle)
            .toolbar {
                // ランキング一覧はオーバーナイト戦略専用。デイトレでは表示しない。
                if strategy == .overnight {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            let range = resolvedRange
                            OvernightWinRateRankingScreen(start: range.start, end: range.end)
                        } label: {
                            Image(systemName: "list.number")
                        }
                    }
                }
            }
        }
    }
}

/// 集計結果カード（入力画面・ランキング詳細画面で共用）
struct OvernightWinRateResultCard: View {
    let result: OvernightWinRateResult

    /// チェックを外した（平均損益率の集計から除外する）曜日の集合
    @State private var excludedWeekdays: Set<Int> = []

    /// 成績一覧の集計単位（年/月/週/日）
    @State private var breakdown: WinRateBreakdown = .year

    /// チェックが入っている曜日だけのトレードを合算した平均損益率（％）。
    /// トレード回数で重み付けするので「その曜日たちだけ売買した場合の実際の平均」になる。
    private var selectedWeekdayAverage: Double? {
        let selected = result.weekdayPerformance.filter { !excludedWeekdays.contains($0.weekday) }
        let totalTrades = selected.reduce(0) { $0 + $1.trades }
        guard totalTrades > 0 else { return nil }
        // averageReturn(%) × trades = その曜日の損益率合計(%) なので、合計 ÷ 総回数で加重平均になる
        let weightedSum = selected.reduce(0.0) { $0 + $1.averageReturn * Double($1.trades) }
        return weightedSum / Double(totalTrades)
    }

    /// 除外中の曜日名（月・火 …）を並べた文字列（成績一覧の注記用）
    private var excludedWeekdayNames: String {
        result.weekdayPerformance
            .filter { excludedWeekdays.contains($0.weekday) }
            .map { $0.shortName }
            .joined(separator: "・")
    }

    /// 曜日チェックに連動した上部サマリー
    private var summary: OvernightWinRateResult.FilteredSummary {
        result.summary(excludingWeekdays: excludedWeekdays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(result.code)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Spacer()
                if let s = result.startDate, let e = result.endDate {
                    Text("\(Self.dateText(s)) 〜 \(Self.dateText(e))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // 勝率（メイン表示）
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", summary.winRate))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(summary.winRate >= 50 ? .red : .blue)
                Text("%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(summary.winRate >= 50 ? .red : .blue)
                Spacer()
            }

            // 曜日チェックを外している場合は、その曜日を除外した集計であることを明示
            if !excludedWeekdays.isEmpty {
                Text("※ \(excludedWeekdayNames) を除外した集計")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }

            Divider()

            statRow(label: "トレード回数", value: "\(summary.totalTrades) 回")
            statRow(label: "勝ち / 負け / 引分", value: "\(summary.wins) / \(summary.losses) / \(summary.draws)")
            statRow(
                label: "1回あたり平均損益率",
                value: String(format: "%+.3f%%", summary.averageReturn),
                color: summary.averageReturn >= 0 ? .red : .blue
            )
            statRow(
                label: result.isCompounding ? "累積リターン（複利/\(result.lotSize)株単位）" : "累積リターン（単利・100株固定）",
                value: String(format: "%+.2f%%", summary.cumulativeReturn),
                color: summary.cumulativeReturn >= 0 ? .red : .blue
            )
            statRow(
                label: "ずっと保有した場合の上昇率",
                value: String(format: "%+.2f%%", result.buyAndHoldReturn),
                color: result.buyAndHoldReturn >= 0 ? .red : .blue
            )

            if !result.weekdayPerformance.isEmpty {
                Divider()
                weekdayList
            }

            if result.equityCurve.count >= 2 {
                Divider()
                equityChart
            }

            if !(result.periodPerformance[.year] ?? []).isEmpty {
                Divider()
                periodList
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// 建玉株数（単利・ずっと保有で使う固定株数）を整数表記した文字列
    private var sharesText: String { "\(Int(result.shares))" }

    private var overnightLabel: String {
        result.isCompounding ? "\(result.strategy.shortLabel)（複利/\(result.lotSize)株単位）" : "\(result.strategy.shortLabel)（単利・\(sharesText)株）"
    }
    private static let overnightNetLabel = "税・金利控除後（手取り）"
    private var buyAndHoldLabel: String { "ずっと保有（\(sharesText)株）" }

    /// 初期投資額をそろえた各戦略の資産推移チャート
    @ViewBuilder
    private var equityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("資産推移（初期投資 = \(OvernightWinRateResultCard.plainYenText(result.initialCapital)) / \(sharesText)株）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Chart(result.equityCurve) { point in
                LineMark(
                    x: .value("日付", point.date),
                    y: .value("評価額", point.overnight)
                )
                .foregroundStyle(by: .value("系列", overnightLabel))

                LineMark(
                    x: .value("日付", point.date),
                    y: .value("評価額", point.overnightNet)
                )
                .foregroundStyle(by: .value("系列", Self.overnightNetLabel))

                LineMark(
                    x: .value("日付", point.date),
                    y: .value("評価額", point.buyAndHold)
                )
                .foregroundStyle(by: .value("系列", buyAndHoldLabel))
            }
            .chartForegroundStyleScale([
                overnightLabel: Color.orange,
                Self.overnightNetLabel: Color.red,
                buyAndHoldLabel: Color.blue
            ])
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let yen = value.as(Double.self) {
                            Text(Self.yenAxisText(yen))
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, spacing: 8)
            .frame(height: 220)
        }
    }

    /// 曜日ごとの平均損益率一覧（エントリー日=買った日の曜日で集計）
    @ViewBuilder
    private var weekdayList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("曜日ごとの成績（エントリー日の曜日）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Text("ペイオフ = 平均利益 ÷ 平均損失。1未満だと負けの方が大きく、勝率が高くても平均はマイナスになりやすい。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // チェックが入っている曜日だけを合算した平均損益率
            HStack {
                Text("選択した曜日の平均損益率")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let avg = selectedWeekdayAverage {
                    Text(String(format: "%+.3f%%", avg))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(avg >= 0 ? .red : .blue)
                } else {
                    Text("—")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)

            // 1行目のヘッダー（先頭にチェックボックスぶんの余白）
            HStack {
                Spacer().frame(width: 28)
                Text("曜日").frame(width: 44, alignment: .leading)
                Text("回数").frame(maxWidth: .infinity, alignment: .trailing)
                Text("勝率").frame(maxWidth: .infinity, alignment: .trailing)
                Text("平均損益率").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            ForEach(result.weekdayPerformance) { w in
                let isSelected = !excludedWeekdays.contains(w.weekday)
                HStack(spacing: 0) {
                    // チェックボックス（タップで集計対象のオン/オフを切り替え）
                    Button {
                        if isSelected {
                            excludedWeekdays.insert(w.weekday)
                        } else {
                            excludedWeekdays.remove(w.weekday)
                        }
                    } label: {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                            .frame(width: 28, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                VStack(spacing: 2) {
                    // 上段: 曜日 / 回数 / 勝率 / 平均損益率
                    HStack {
                        Text(w.shortName)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 44, alignment: .leading)
                        Text("\(w.trades)")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", w.winRate))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.secondary)
                        Text(String(format: "%+.3f%%", w.averageReturn))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(w.averageReturn >= 0 ? .red : .blue)
                    }
                    .font(.system(size: 13, design: .monospaced))

                    // 下段: 平均利益 / 平均損失 / ペイオフ / 最大の負け（色は付けず控えめに表示）
                    HStack {
                        Spacer().frame(width: 44)
                        weekdaySubMetric(title: "平均利益", value: String(format: "%+.2f%%", w.averageWin))
                        weekdaySubMetric(title: "平均損失", value: String(format: "%+.2f%%", w.averageLoss))
                        weekdaySubMetric(title: "ペイオフ", value: w.payoffRatio.map { String(format: "%.2f", $0) } ?? "—")
                        weekdaySubMetric(title: "最大の負け", value: String(format: "%.2f%%", w.worstReturn))
                    }
                }
                }
                .opacity(isSelected ? 1 : 0.4)
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected && w.averageReturn < 0 ? Color.blue.opacity(0.08) : Color.clear)
                )
            }
        }
    }

    /// 曜日行の下段に並べる小さな指標セル（見出し＋値の縦2段。色は付けず控えめに表示）
    private func weekdaySubMetric(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// 期間ごとのパフォーマンス一覧（年/月/週/日を切り替え可能）
    @ViewBuilder
    private var periodList: some View {
        // 件数が多い（日・週など）と描画が重いので直近ぶんだけ表示する
        let cap = 200
        let full = result.periodPerformanceList(breakdown: breakdown, excludingWeekdays: excludedWeekdays)
        let truncated = full.count > cap
        let list = truncated ? Array(full.suffix(cap)) : full

        VStack(alignment: .leading, spacing: 8) {
            Text(result.isCompounding ? "期間ごとの成績（複利/\(result.lotSize)株単位 / 保有=\(sharesText)株）" : "期間ごとの成績（\(sharesText)株）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            // 集計単位の切り替え（年/月/週/日）
            Picker("集計単位", selection: $breakdown) {
                ForEach(WinRateBreakdown.allCases) { b in
                    Text(b.rawValue).tag(b)
                }
            }
            .pickerStyle(.segmented)

            Label("★ = \(result.strategy.shortLabel)がずっと保有を上回った\(breakdown.rawValue)", systemImage: "star.fill")
                .labelStyle(.titleOnly)
                .font(.system(size: 11))
                .foregroundColor(.orange)

            // 曜日チェックを外している場合は、その曜日を除外して集計していることを明示
            if !excludedWeekdays.isEmpty {
                Text("※ チェックを外した曜日（\(excludedWeekdayNames)）を除外して集計")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }

            if truncated {
                Text("※ 件数が多いため直近\(cap)件のみ表示")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // ヘッダー
            HStack {
                Text(breakdown.rawValue).frame(width: 68, alignment: .leading)
                Text("勝率").frame(maxWidth: .infinity, alignment: .trailing)
                Text("元本").frame(maxWidth: .infinity, alignment: .trailing)
                Text(result.strategy.shortLabel).frame(maxWidth: .infinity, alignment: .trailing)
                Text("ずっと保有").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            ForEach(list) { p in
                let overnightWins = p.overnightProfit > p.buyAndHoldProfit
                VStack(spacing: 2) {
                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                                .opacity(overnightWins ? 1 : 0)
                            Text(p.label)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(width: 68, alignment: .leading)
                        Text(p.trades > 0 ? String(format: "%.0f%%", p.winRate) : "—")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.secondary)
                        Text(Self.plainYenText(p.principal))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        amountCell(yen: p.overnightProfit, percent: p.overnightProfitPercent, bold: overnightWins)
                        amountCell(yen: p.buyAndHoldProfit, percent: p.buyAndHoldProfitPercent, bold: false)
                    }
                    .font(.system(size: 13, design: .monospaced))

                    // 日単位のときだけ、その日の買値→売値を表示
                    if breakdown == .day, let buy = p.buyPrice, let sell = p.sellPrice {
                        HStack(spacing: 4) {
                            Spacer().frame(width: 68)
                            Text("買 \(Self.priceText(buy)) → 売 \(Self.priceText(sell))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(overnightWins ? Color.orange.opacity(0.12) : Color.clear)
                )
            }
        }
    }

    /// 金額（円）と元本に対する損益率（％）を縦に並べたセル
    private func amountCell(yen: Double, percent: Double, bold: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(Self.signedYenText(yen))
                .fontWeight(bold ? .bold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Self.signedPercentText(percent))
                .font(.system(size: 10, design: .monospaced))
                .opacity(0.75)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .foregroundColor(yen >= 0 ? .red : .blue)
    }

    /// 損益率を符号付きのパーセント表示にする（例: +12.3% / -3.4%）
    static func signedPercentText(_ percent: Double) -> String {
        String(format: "%+.1f%%", percent)
    }

    /// 損益を符号付きの円表示にする（例: +12,300円 / -3,400円）
    static func signedYenText(_ yen: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let absText = f.string(from: NSNumber(value: abs(yen))) ?? "0"
        let sign = yen >= 0 ? "+" : "-"
        return "\(sign)\(absText)円"
    }

    /// 株価を区切り付きで表示する（例: 157,400）
    static func priceText(_ price: Float) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    /// 元本など符号なしの円表示にする（例: 123,000円）
    static func plainYenText(_ yen: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let text = f.string(from: NSNumber(value: yen)) ?? "0"
        return "\(text)円"
    }

    /// Y軸ラベル用に円を「万」単位で短く表示する
    static func yenAxisText(_ yen: Double) -> String {
        if abs(yen) >= 10_000 {
            return String(format: "%.0f万", yen / 10_000)
        }
        return String(format: "%.0f", yen)
    }

    @ViewBuilder
    private func statRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}

#Preview {
    OvernightWinRateScreen()
}
