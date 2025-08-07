//
//  StockWinningRate.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/07.
//

import SwiftData

@Model
final class StockWinningRate: Identifiable, Hashable {
    var month: YuutaiMonth
    var name: String
    var code: String
    var creditType: String?
    var stockChartData: [MyStockChartData]
    
    var winningRate: Float
    var totalCount: Int
    
    init(month: YuutaiMonth, yuutaiInfo: TanosiiYuutaiInfo, stockChartData: [MyStockChartData], winningRate: Float, totalCount: Int) {
        self.month = month
        self.name = yuutaiInfo.name
        self.code = yuutaiInfo.code
        self.creditType = yuutaiInfo.creditType
        self.stockChartData = stockChartData
        self.winningRate = winningRate
        self.totalCount = totalCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(month)
        hasher.combine(name)
        hasher.combine(code)
        hasher.combine(creditType)
    }
    
    static func == (lhs: StockWinningRate, rhs: StockWinningRate) -> Bool {
        return lhs.month == rhs.month &&
        lhs.name == rhs.name &&
        lhs.code == rhs.code &&
        lhs.creditType == rhs.creditType
    }
}
