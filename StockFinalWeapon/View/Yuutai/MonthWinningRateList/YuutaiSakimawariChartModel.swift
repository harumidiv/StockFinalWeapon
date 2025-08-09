//
//  YuutaiSakimawariChartModel.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/07.
//

import SwiftData
import Foundation

@Model
final class YuutaiSakimawariChartModel: Identifiable, Hashable {
    var month: YuutaiMonth
    var name: String
    var code: String
    var creditType: String?
    var stockChartData: [MyStockChartData]
    // FIXME: ここで持つべきじゃないかもしれないが、リスト表示時に計算すると重くなってしまうので要検討
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
}

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
