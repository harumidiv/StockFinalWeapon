//
//  StockChartPairData.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/13.
//

import Foundation
import SwiftYFinance

struct StockChartPairData: Identifiable {
    var id = UUID()
    
    let purchase: StockChartData?
    let sale: StockChartData?
    
    // 購入日から売却日までの最大値
    var highestPrice: Float?
    // 購入日から売却日までの最小値
    var lowestPrice: Float?
    
    var valueChangeParcent: Float? {
        if let purchasePrice = self.purchase?.adjclose,
           let salePrice = self.sale?.adjclose {
            let diff = calculateRisePercentage(from: purchasePrice, to: salePrice)
            return round(diff * 10) / 10
        }
        return nil
    }
    
    var purchaseDateString: String {
        if let purchaseDate = self.purchase?.date {
            return formatter.string(from: purchaseDate)
        } else {
            return "---"
        }
        
    }
    
    var saleDateString: String {
        if let saleDate = self.sale?.date {
            return formatter.string(from: saleDate)
        } else {
            return "---"
        }
    }
    
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }
    
    // 変化率の計算
    private func calculateRisePercentage(from oldValue: Float, to newValue: Float) -> Float {
        guard oldValue != 0 else { return 0 } // 0除算対策
        return ((newValue - oldValue) / oldValue) * 100
    }
}
