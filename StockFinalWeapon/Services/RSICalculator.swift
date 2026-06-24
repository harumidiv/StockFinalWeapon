//
//  RSICalculator.swift
//  StockFinalWeapon
//
//  RSI（相対力指数）を計算するユーティリティ
//

import Foundation

enum RSICalculator {
    /// RSIの計算方式
    enum Method {
        /// ワイルダー方式（修正移動平均/RMA）。TradingViewなどの標準。
        case wilder
        /// 単純合計方式（カトラー式）。直近N日間の上げ幅合計÷(上げ幅合計+下げ幅合計)。
        /// 楽天証券マーケットスピードなど、日本の証券ツールで多く採用される。
        case simple
    }

    /// 終値配列から最新時点のRSIを返す。
    /// - Parameters:
    ///   - closes: 終値の配列（日付昇順で渡すこと）
    ///   - period: 期間（楽天証券の短期は9、ワイルダー標準は14）
    ///   - method: 計算方式（.wilder / .simple）
    /// - Returns: 0〜100のRSI。データが `period + 1` 本に満たない場合は nil。
    static func rsi(closes: [Double], period: Int = 14, method: Method = .wilder) -> Double? {
        guard period > 0, closes.count >= period + 1 else { return nil }

        switch method {
        case .simple:
            // 直近 period 日間の値動きの「上げ幅合計」と「下げ幅合計」から算出
            var gains = 0.0
            var losses = 0.0
            for i in (closes.count - period)..<closes.count {
                let change = closes[i] - closes[i - 1]
                if change >= 0 { gains += change } else { losses -= change }
            }
            let denominator = gains + losses
            guard denominator != 0 else { return 100 }
            return gains / denominator * 100

        case .wilder:
            // 最初の period ぶんの値動きから初期の平均上昇幅・平均下落幅を作る
            var gains = 0.0
            var losses = 0.0
            for i in 1...period {
                let change = closes[i] - closes[i - 1]
                if change >= 0 { gains += change } else { losses -= change }
            }
            var avgGain = gains / Double(period)
            var avgLoss = losses / Double(period)

            // Wilderのスムージングで最新の終値まで更新していく
            if closes.count > period + 1 {
                for i in (period + 1)..<closes.count {
                    let change = closes[i] - closes[i - 1]
                    let gain = change >= 0 ? change : 0
                    let loss = change < 0 ? -change : 0
                    avgGain = (avgGain * Double(period - 1) + gain) / Double(period)
                    avgLoss = (avgLoss * Double(period - 1) + loss) / Double(period)
                }
            }

            guard avgLoss != 0 else { return 100 }
            let rs = avgGain / avgLoss
            return 100 - 100 / (1 + rs)
        }
    }
}
