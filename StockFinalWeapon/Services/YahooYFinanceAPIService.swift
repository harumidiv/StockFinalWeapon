//
//  YahooYFinanceAPIService.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/07.
//

import Foundation
@preconcurrency import SwiftYFinance

struct YahooYFinanceAPIService {
    ///  APIからチャートデータを取得する
    /// - Parameters:
    ///   - code: 銘柄コード
    ///   - symbol: Yahoofinanceでの市場のシンボル
    ///   - startDate: 計測開始日
    ///   - endDate: 計測終了日
    /// - Returns: 通信結果
    func fetchStockChartData(code: String, symbol: String = "T", startDate: Date, endDate: Date) async -> Result<[MyStockChartData], Error> {
        do {
            let data = try await SwiftYFinanceHelper.fetchChartData(
                identifier: "\(code).\(symbol)",
                start: startDate,
                end: endDate
            )
            return .success(data.compactMap{ MyStockChartData(stockChartData: $0)})
        } catch {
            return .failure(error)
        }
    }

    /// 「前場引け（11:30頃）で買い、後場寄り（12:30）で売る」戦略を検証するための合成日足を取得する。
    /// 30分足を日ごとにまとめ、`open`=前場引け・`close`=後場寄り とした1日1本のデータに変換して返す。
    /// ※ 30分足はYahoo Finance側の制限で「直近約60日」までしか取得できない。
    /// - Parameters:
    ///   - code: 銘柄コード
    ///   - symbol: Yahoo Financeでの市場のシンボル
    ///   - startDate: 計測開始日
    ///   - endDate: 計測終了日
    /// - Returns: 通信結果（合成日足の配列）
    func fetchLunchBreakBars(code: String, symbol: String = "T", startDate: Date, endDate: Date) async -> Result<[MyStockChartData], Error> {
        do {
            let raw = try await SwiftYFinanceHelper.fetchChartData(
                identifier: "\(code).\(symbol)",
                start: startDate,
                end: endDate,
                interval: .thirtyminutes
            )
            return .success(Self.buildLunchBreakDailyBars(from: raw))
        } catch {
            return .failure(error)
        }
    }

    /// 30分足を日（JST）ごとにまとめ、前場引け→後場寄りの合成日足に変換する。
    /// - 前場引け(買値): 昼(12:00 JST)より前の最後の足の終値（＝11:30の前引け値）
    /// - 後場寄り(売値): 昼(12:00 JST)以降の最初の足の始値（＝12:30の後場寄り値。昼休みの12:00足は欠損なので12:30が拾われる）
    /// - 前場・後場の両方が揃わない日は除外する
    static func buildLunchBreakDailyBars(from bars: [StockChartData]) -> [MyStockChartData] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

        // 有効な足だけを時刻昇順に整理
        let valid = bars
            .compactMap { b -> (date: Date, open: Float, close: Float)? in
                guard let d = b.date, let o = b.open, let c = b.close, o > 0, c > 0 else { return nil }
                return (d, o, c)
            }
            .sorted { $0.date < $1.date }

        // 日（JST）ごとにグループ化（初出順を保持）
        var groups: [Date: [(date: Date, open: Float, close: Float)]] = [:]
        var order: [Date] = []
        for bar in valid {
            let day = calendar.startOfDay(for: bar.date)
            if groups[day] == nil { order.append(day) }
            groups[day, default: []].append(bar)
        }

        var result: [MyStockChartData] = []
        for day in order {
            let dayBars = groups[day]!
            let morning = dayBars.filter { calendar.component(.hour, from: $0.date) < 12 }
            let afternoon = dayBars.filter { calendar.component(.hour, from: $0.date) >= 12 }
            guard let buy = morning.last?.close, let sell = afternoon.first?.open else { continue }
            result.append(MyStockChartData(date: day, open: buy, close: sell))
        }
        return result
    }
}
