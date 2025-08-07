import Foundation
@preconcurrency import SwiftYFinance

struct YuutaiUtil {
    
    /// 勝率を数値で返却する
    /// - Parameter data: 比較するデータ
    /// - Returns: 勝率
    static func riseRateString(for data: [StockChartPairData]) -> Float {
        let valid = data.compactMap { $0.valueChangeParcent }
        guard !valid.isEmpty else { return 0 }
        
        let rising = valid.filter { $0 > 0 }.count
        let percent = Float(rising) / Float(valid.count) * 100
        
        return percent
    }
    
    
    /// 検証を行った回数
    /// - Parameter data: 比較するデータ
    /// - Returns: 検証を行う回数(IPO銘柄の場合比較回数が少なくなるので)
    static func trialCount(for data: [StockChartPairData]) -> Int {
        return data.compactMap { $0.valueChangeParcent }.count
    }
    
    
    /// 勝率をパーセント付きで返却する
    /// - Parameter data: 比較するデータ
    /// - Returns: 勝率%付き
    static func riseRateString(for data: [StockChartPairData]) -> String {
        let valid = data.compactMap { $0.valueChangeParcent }
        guard !valid.isEmpty else { return "―" }
        
        let rising = valid.filter { $0 >= 0 }.count
        let percent = Float(rising) / Float(valid.count) * 100
        
        return String(format: "%.1f%%", percent)
    }
    
    /// 値上がりを検証する
    /// - Parameters:
    ///   - stockChartData: 株価データ
    ///   - purchaseDay: 購入日
    ///   - saleDay: 売却日
    /// - Returns: 結果のリスト
    static func fetchStockPrice(
        stockChartData: [MyStockChartData],
        purchaseDay: Date,
        saleDay: Date
    ) async -> [StockChartPairData] {
        let purchaseDayList = await extractPurchaseDataNearTargetDate(from: stockChartData, targetMonthDay: purchaseDay)
        let saleDayList = await extractPurchaseDataNearTargetDate(from: stockChartData, targetMonthDay: saleDay)

        let calendar = Calendar.current
        var result: [StockChartPairData] = []

        for purchase in purchaseDayList {
            guard let purchaseDate = purchase.date else { continue }
            let year = calendar.component(.year, from: purchaseDate)

            let sameYearSale = saleDayList.first {
                guard let saleDate = $0.date else { return false }
                return calendar.component(.year, from: saleDate) == year
            }

            if let sameYearSaleDate = sameYearSale?.date {
                let maxAndmin = findHighLowAdjClose(in: stockChartData, from: purchaseDate, to: sameYearSaleDate)
                result.append(StockChartPairData(purchase: purchase, sale: sameYearSale, highestPrice: maxAndmin.max, lowestPrice: maxAndmin.min))
            } else {
                result.append(StockChartPairData(purchase: purchase, sale: sameYearSale))
            }
        }
        return result
    }
    
    /// 値上がりを検証する
    /// - Parameters:
    ///   - code: 銘柄コード
    ///   - startDate: 検証開始日
    ///   - endDate: 検証終了日
    ///   - purchaseDay: 購入日
    ///   - saleDay: 売却日
    /// - Returns: 結果のリスト
    static func fetchStockPrice(
        code: String,
        startDate: Date,
        endDate: Date,
        purchaseDay: Date,
        saleDay: Date
    ) async -> Result<[StockChartPairData], Error> {
        let result = await YahooYFinanceAPIService().fetchStockChartData(code: code, startDate: startDate, endDate: endDate)
        switch result {
        case .success(let chartData):
            let purchaseDayList = await extractPurchaseDataNearTargetDate(from: chartData, targetMonthDay: purchaseDay)
            let saleDayList = await extractPurchaseDataNearTargetDate(from: chartData, targetMonthDay: saleDay)

            let calendar = Calendar.current
            var result: [StockChartPairData] = []

            for purchase in purchaseDayList {
                guard let purchaseDate = purchase.date else { continue }
                let year = calendar.component(.year, from: purchaseDate)

                let sameYearSale = saleDayList.first {
                    guard let saleDate = $0.date else { return false }
                    return calendar.component(.year, from: saleDate) == year
                }

                if let sameYearSaleDate = sameYearSale?.date {
                    let maxAndmin = findHighLowAdjClose(in: chartData, from: purchaseDate, to: sameYearSaleDate)
                    result.append(StockChartPairData(purchase: purchase, sale: sameYearSale, highestPrice: maxAndmin.max, lowestPrice: maxAndmin.min))
                } else {
                    result.append(StockChartPairData(purchase: purchase, sale: sameYearSale))
                }
            }
            return .success(result)
        case .failure(let error):
            return .failure(error)
        }
    }

    static func findHighLowAdjClose(
        in data: [MyStockChartData],
        from startDate: Date,
        to endDate: Date
    ) -> (min: Float?, max: Float?) {
        let filtered = data.filter {
            guard let date = $0.date else { return false }
            return date >= startDate && date <= endDate
        }
        let adjcloses = filtered.compactMap { $0.adjclose }
        let min = adjcloses.min()
        let max = adjcloses.max()
        return (min, max)
    }

    /// 各年の特定日のデータを取得する、取得できない場合は近くの日付を取得
    /// - Parameters:
    ///   - data: 株価データ
    ///   - targetMonthDay: 特定の日付、年は使わないので適当でOK
    ///   - searchDayOffsets: 前後3日までの値で一番初めに見つかった値を使用
    /// - Returns: 毎年の特定の日付もしくは近い日付の株価のデータ
    static func extractPurchaseDataNearTargetDate(
        from data: [MyStockChartData],
        targetMonthDay: Date,
        searchDayOffsets: [Int] = [-1, 1, -2, 2, -3, 3]
    ) async -> [MyStockChartData] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let calendar = Calendar.current
                var result: [MyStockChartData] = []
                let groupedByYear = Dictionary(grouping: data.compactMap { $0.date }, by: {
                    calendar.component(.year, from: $0)
                })

                for (year, _) in groupedByYear {
                    guard let baseDate = calendar.date(from: DateComponents(
                        year: year,
                        month: calendar.component(.month, from: targetMonthDay),
                        day: calendar.component(.day, from: targetMonthDay)
                    )) else {
                        continue
                    }

                    if let exact = data.first(where: {
                        guard let d = $0.date else { return false }
                        return calendar.isDate(d, inSameDayAs: baseDate)
                    }) {
                        result.append(exact)
                        continue
                    }

                    for offset in searchDayOffsets {
                        if let altDate = calendar.date(byAdding: .day, value: offset, to: baseDate),
                           let near = data.first(where: {
                               guard let d = $0.date else { return false }
                               return calendar.isDate(d, inSameDayAs: altDate)
                           }) {
                            result.append(near)
                            break
                        }
                    }
                }

                let sortedResult = result.sorted {
                    guard let d1 = $0.date, let d2 = $1.date else { return false }
                    return d1 < d2
                }

                continuation.resume(returning: sortedResult)
            }
        }
    }
}
