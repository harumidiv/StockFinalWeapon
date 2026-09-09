//
//  RSIBacktester.swift
//  StockFinalWeapon
//
//  RSIの買い・売り閾値を使った現物1ポジションのバックテスト。
//

import Foundation

enum RSIBacktester {
    struct Trade: Identifiable {
        let buyDate: Date
        let buyPrice: Double
        let buyRSI: Double
        let sellDate: Date
        let sellPrice: Double
        let sellRSI: Double

        var id: Date { sellDate }
        var returnPercentage: Double { (sellPrice / buyPrice - 1) * 100 }
    }

    struct OpenPosition {
        let buyDate: Date
        let buyPrice: Double
        let buyRSI: Double
        let latestDate: Date
        let latestPrice: Double

        var returnPercentage: Double { (latestPrice / buyPrice - 1) * 100 }
    }

    struct Result {
        let startDate: Date
        let endDate: Date
        let trades: [Trade]
        let openPosition: OpenPosition?
        let totalReturnPercentage: Double
        let realizedReturnPercentage: Double
        let buyAndHoldReturnPercentage: Double

        var winCount: Int {
            trades.count { $0.returnPercentage > 0 }
        }

        var winRatePercentage: Double? {
            guard !trades.isEmpty else { return nil }
            return Double(winCount) / Double(trades.count) * 100
        }

        var averageTradeReturnPercentage: Double? {
            guard !trades.isEmpty else { return nil }
            return trades.map(\.returnPercentage).reduce(0, +) / Double(trades.count)
        }
    }

    /// RSIが買い閾値以下ならその日の終値で買い、売り閾値以上ならその日の終値で売る。
    /// 常に全資金を投入する前提で、各取引の収益を複利でつなぐ。
    static func run(
        dates: [Date],
        closes: [Double],
        period: Int,
        method: RSICalculator.Method,
        buyThreshold: Double,
        sellThreshold: Double,
        startingAt requestedStartDate: Date
    ) -> Result? {
        guard dates.count == closes.count,
              closes.count >= period + 1,
              period > 0,
              (0...100).contains(buyThreshold),
              (0...100).contains(sellThreshold),
              buyThreshold < sellThreshold else {
            return nil
        }

        let rsiValues = RSICalculator.rsiSeries(
            closes: closes,
            period: period,
            method: method
        )
        let testIndices = dates.indices.filter {
            dates[$0] >= requestedStartDate && closes[$0].isFinite && closes[$0] > 0
        }
        guard let firstIndex = testIndices.first,
              let lastIndex = testIndices.last else {
            return nil
        }

        struct Entry {
            let date: Date
            let price: Double
            let rsi: Double
        }

        var entry: Entry?
        var trades: [Trade] = []
        var realizedGrowth = 1.0

        for index in testIndices {
            guard let rsi = rsiValues[index] else { continue }
            let price = closes[index]

            if let currentEntry = entry {
                if rsi >= sellThreshold {
                    let trade = Trade(
                        buyDate: currentEntry.date,
                        buyPrice: currentEntry.price,
                        buyRSI: currentEntry.rsi,
                        sellDate: dates[index],
                        sellPrice: price,
                        sellRSI: rsi
                    )
                    trades.append(trade)
                    realizedGrowth *= price / currentEntry.price
                    entry = nil
                }
            } else if rsi <= buyThreshold {
                entry = Entry(date: dates[index], price: price, rsi: rsi)
            }
        }

        let latestDate = dates[lastIndex]
        let latestPrice = closes[lastIndex]
        let openPosition = entry.map {
            OpenPosition(
                buyDate: $0.date,
                buyPrice: $0.price,
                buyRSI: $0.rsi,
                latestDate: latestDate,
                latestPrice: latestPrice
            )
        }
        let totalGrowth = openPosition.map {
            realizedGrowth * ($0.latestPrice / $0.buyPrice)
        } ?? realizedGrowth

        return Result(
            startDate: dates[firstIndex],
            endDate: latestDate,
            trades: trades,
            openPosition: openPosition,
            totalReturnPercentage: (totalGrowth - 1) * 100,
            realizedReturnPercentage: (realizedGrowth - 1) * 100,
            buyAndHoldReturnPercentage: (latestPrice / closes[firstIndex] - 1) * 100
        )
    }
}
