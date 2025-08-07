//
//  StockCodeTag.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/03.
//

import Foundation
import SwiftYFinance

enum WinOrLose: String {
    case win = "勝ち"
    case lose = "負け"
    case unsettled = "未定"
    case error = "エラー"
    
    var image: String {
        switch self {
        case .win:
            return "win"
        case .lose:
            return "lose"
        case .unsettled:
            return "draw"
        case .error:
            return "error"
        }
    }
}

struct StockCodeTag: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let market: Market
    let chartData: [MyStockChartData]
    
    func winOrLose(start: Date, end: Date, profitFixed: Int, lossCut: Int) -> WinOrLose {
        let rangeData = chartData.filter { chart in
            if let date = chart.date {
                return date >= start && date <= end
            } else {
                return false
            }
        }
        
        guard let startPrice = rangeData.first?.open else {
            return .error
        }
        
        var winOrLose: WinOrLose?
        
        rangeData.forEach { value in
            guard let high = value.high, let low = value.low, winOrLose == nil else {
                return
            }
            
            let highPriceDifference = high - startPrice
            let highPercent = highPriceDifference / startPrice * 100
            // 高値が始まり値より高い + 高値が利確値よりも高い
            if high >= startPrice && highPercent > Float(profitFixed) {
                winOrLose = .win
            }
            
            let lowPriceDifference = low - startPrice
            let lowParcent = lowPriceDifference / startPrice * 100
            // 安値が始まり値よりも低い + 安値が損切り値よりも低い
            if low <= startPrice && lowParcent < Float(-lossCut) {
                winOrLose = .lose
            }
            
            print("code: \(code), high: \(high), low: \(low), highPercent: \(highPercent), lowParcent: \(lowParcent)")
        }
        return winOrLose ?? .unsettled
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(code)
        hasher.combine(market)
    }
    
    static func == (lhs: StockCodeTag, rhs: StockCodeTag) -> Bool {
        return lhs.id == rhs.id &&
        lhs.code == rhs.code &&
        lhs.market == rhs.market
    }
}
