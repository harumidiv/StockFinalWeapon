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

    /// 任意の値から直接生成する（分足を合成した日足など、APIレスポンス以外から作る用途）
    init(date: Date?, open: Float?, close: Float?, high: Float? = nil, low: Float? = nil, adjclose: Float? = nil, volume: Int? = nil) {
        self.date = date
        self.open = open
        self.close = close
        self.high = high
        self.low = low
        self.adjclose = adjclose ?? close
        self.volume = volume
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
