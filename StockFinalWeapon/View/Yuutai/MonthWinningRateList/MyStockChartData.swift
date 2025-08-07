//
//  MyStockChartData.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/07.
//

import SwiftData
import Foundation
import SwiftYFinance

@Model
final class MyStockChartData {
    var date: Date?
    var volume: Int?
    var open: Float?
    var close: Float?
    var adjclose: Float?
    var low: Float?
    var high: Float?
    
    init(stockChartData: StockChartData) {
        date = stockChartData.date
        volume = stockChartData.volume
        open = stockChartData.open
        close = stockChartData.close
        adjclose = stockChartData.adjclose
        low = stockChartData.low
        high = stockChartData.high
    }
    
    init(sendableStockChartData: MyStockChartDataSendable) {
        date = sendableStockChartData.date
        volume = sendableStockChartData.volume
        open = sendableStockChartData.open
        close = sendableStockChartData.close
        adjclose = sendableStockChartData.adjclose
        low = sendableStockChartData.low
        high = sendableStockChartData.high
    }
}

struct MyStockChartDataSendable: Sendable {
    var date: Date?
    var volume: Int?
    var open: Float?
    var close: Float?
    var adjclose: Float?
    var low: Float?
    var high: Float?
    
    init(stockChartData: MyStockChartData) {
        date = stockChartData.date
        volume = stockChartData.volume
        open = stockChartData.open
        close = stockChartData.close
        adjclose = stockChartData.adjclose
        low = stockChartData.low
        high = stockChartData.high
    }
}
