//
//  StockWinningRate.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/09.
//

import Foundation

struct StockWinningRate: Identifiable, Hashable {
    let id: UUID = UUID()
    let month: YuutaiMonth
    let name: String
    let code: String
    let creditType: String?
    let stockChartData: [MyStockChartData]
    let winningRate: Float
    let totalCount: Int
    
    init(chartModel: YuutaiSakimawariChartModel, winningRate: Float, totalCount: Int) {
        self.month = chartModel.month
        self.name = chartModel.name
        self.code = chartModel.code
        self.creditType = chartModel.creditType
        self.stockChartData = chartModel.stockChartData
        self.winningRate = winningRate
        self.totalCount = totalCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(code)
        hasher.combine(creditType)
    }

    static func == (lhs: StockWinningRate, rhs: StockWinningRate) -> Bool {
        return lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.code == rhs.code &&
        lhs.creditType == rhs.creditType
    }
}
