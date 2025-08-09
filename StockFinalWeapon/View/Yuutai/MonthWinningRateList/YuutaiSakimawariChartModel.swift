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
    
    init(month: YuutaiMonth, yuutaiInfo: TanosiiYuutaiInfo, stockChartData: [MyStockChartData]) {
        self.month = month
        self.name = yuutaiInfo.name
        self.code = yuutaiInfo.code
        self.creditType = yuutaiInfo.creditType
        self.stockChartData = stockChartData
    }
    
    init(month: YuutaiMonth, name: String, code: String, creditType: String?, stockChartData: [MyStockChartData]) {
        self.month = month
        self.name = name
        self.code = code
        self.creditType = creditType
        self.stockChartData = stockChartData
    }
}
