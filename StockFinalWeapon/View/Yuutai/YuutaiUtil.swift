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
    
    /// 対象銘柄の株価データを引っ張る
    /// - Parameter code: 銘柄コード
    /// - Returns: 株価データの配列
    static func fetchStockData(code: String) async -> Result<[MyStockChartData], Error> {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        // 存在しないデータはスキップされるのでかなり昔から取得
        let start = dateFormatter.date(from: "1980/1/3")!
        
        do {
            let data = try await SwiftYFinanceHelper.fetchChartData(
                identifier: "\(code).T",
                start: start,
                end: Date()
            )
            return .success(data.compactMap{ MyStockChartData(stockChartData: $0)})
        } catch {
            return .failure(error)
        }
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
        do {
            let data = try await SwiftYFinanceHelper.fetchChartData(
                identifier: "\(code).T",
                start: startDate,
                end: endDate
            ).compactMap{ MyStockChartData(stockChartData: $0)}

            let purchaseDayList = await extractPurchaseDataNearTargetDate(from: data, targetMonthDay: purchaseDay)
            let saleDayList = await extractPurchaseDataNearTargetDate(from: data, targetMonthDay: saleDay)

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
                    let maxAndmin = findHighLowAdjClose(in: data, from: purchaseDate, to: sameYearSaleDate)
                    result.append(StockChartPairData(purchase: purchase, sale: sameYearSale, highestPrice: maxAndmin.max, lowestPrice: maxAndmin.min))
                } else {
                    result.append(StockChartPairData(purchase: purchase, sale: sameYearSale))
                }
            }
            return .success(result)
        } catch {
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
