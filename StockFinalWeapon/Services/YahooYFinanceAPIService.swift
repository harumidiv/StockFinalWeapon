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
}
