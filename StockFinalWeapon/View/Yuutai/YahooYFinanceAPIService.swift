//
//  YahooYFinanceAPIService.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/07.
//

import Foundation
@preconcurrency import SwiftYFinance

struct YahooYFinanceAPIService {
    /// 対象銘柄の株価データを引っ張る
    /// - Parameter code: 銘柄コード
    /// - Returns: 株価データの配列
    func fetchStockData(code: String, symbol: String = "T", startDate: Date, endDate: Date) async -> Result<[MyStockChartData], Error> {
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
