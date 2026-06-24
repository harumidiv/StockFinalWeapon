// Create SwiftYFinanceHelper.swift
// Utility for fetching chart data via SwiftYFinance
import Foundation
import SwiftYFinance

final class SwiftYFinanceHelper {
    /// Fetch chart data via SwiftYFinance in async/await style
    static func fetchChartData(identifier: String, start: Date, end: Date) async throws -> [StockChartData] {
        return try await withCheckedThrowingContinuation { continuation in
            SwiftYFinance.chartDataBy(identifier: identifier, start: start, end: end) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: NSError(domain: "DataError", code: -1, userInfo: nil))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    /// 日足の終値を日付昇順の配列で取得する（RSIなどの指標計算用）
    static func fetchDailyCloses(identifier: String, start: Date, end: Date) async throws -> [Double] {
        let data = try await fetchChartData(identifier: identifier, start: start, end: end)
        return data
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            .compactMap { $0.close.map(Double.init) }
    }
}
