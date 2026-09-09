//
//  RSICalculator.swift
//  StockFinalWeapon
//
//  RSI（相対力指数）を計算するユーティリティ
//

import Foundation

enum RSICalculator {
    /// RSIの計算方式
    enum Method: String, CaseIterable, Identifiable {
        /// ワイルダー方式（修正移動平均/RMA）。TradingViewなどの標準。
        case wilder
        /// 単純合計方式（カトラー式）。直近N日間の上げ幅合計÷(上げ幅合計+下げ幅合計)。
        /// 楽天証券マーケットスピードなど、日本の証券ツールで多く採用される。
        case simple

        var id: Self { self }

        var title: String {
            switch self {
            case .wilder: return "Wilder"
            case .simple: return "単純"
            }
        }
    }

    /// 終値配列から最新時点のRSIを返す。
    /// - Parameters:
    ///   - closes: 終値の配列（日付昇順で渡すこと）
    ///   - period: 期間（楽天証券の短期は9、ワイルダー標準は14）
    ///   - method: 計算方式（.wilder / .simple）
    /// - Returns: 0〜100のRSI。データが `period + 1` 本に満たない場合は nil。
    static func rsi(closes: [Double], period: Int = 14, method: Method = .wilder) -> Double? {
        guard let latest = rsiSeries(closes: closes, period: period, method: method).last else {
            return nil
        }
        return latest
    }

    /// 各終値時点のRSIを、入力と同じ要素数で返す。
    /// RSIを計算できない先頭 `period` 本は nil。
    static func rsiSeries(closes: [Double], period: Int = 14, method: Method = .wilder) -> [Double?] {
        var values = Array<Double?>(repeating: nil, count: closes.count)
        guard period > 0, closes.count >= period + 1 else { return values }

        switch method {
        case .simple:
            // 最初の period 日間を集計し、以降は窓から外れる値動きと新しい値動きだけを反映する。
            var gains = 0.0
            var losses = 0.0
            for i in 1...period {
                let change = closes[i] - closes[i - 1]
                if change >= 0 { gains += change } else { losses -= change }
            }
            values[period] = rsiValue(gains: gains, losses: losses)

            if closes.count > period + 1 {
                for i in (period + 1)..<closes.count {
                    let outgoing = closes[i - period] - closes[i - period - 1]
                    if outgoing >= 0 { gains -= outgoing } else { losses += outgoing }

                    let incoming = closes[i] - closes[i - 1]
                    if incoming >= 0 { gains += incoming } else { losses -= incoming }

                    // 浮動小数点誤差で僅かに負になるのを防ぐ。
                    gains = max(0, gains)
                    losses = max(0, losses)
                    values[i] = rsiValue(gains: gains, losses: losses)
                }
            }

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
            values[period] = rsiValue(gains: avgGain, losses: avgLoss)

            // Wilderのスムージングで最新の終値まで更新していく
            if closes.count > period + 1 {
                for i in (period + 1)..<closes.count {
                    let change = closes[i] - closes[i - 1]
                    let gain = change >= 0 ? change : 0
                    let loss = change < 0 ? -change : 0
                    avgGain = (avgGain * Double(period - 1) + gain) / Double(period)
                    avgLoss = (avgLoss * Double(period - 1) + loss) / Double(period)
                    values[i] = rsiValue(gains: avgGain, losses: avgLoss)
                }
            }
        }

        return values
    }

    /// 現在までの終値に1本追加した際、指定RSIに到達する次の終値を逆算する。
    /// 株価を0以上として到達できない値は nil。
    static func nextClose(
        toReach targetRSI: Double,
        closes: [Double],
        period: Int = 14,
        method: Method = .wilder
    ) -> Double? {
        guard targetRSI > 0,
              targetRSI < 100,
              period > 0,
              closes.count >= period + 1,
              let latestClose = closes.last,
              latestClose > 0 else {
            return nil
        }

        func nextRSI(at price: Double) -> Double? {
            rsi(closes: closes + [price], period: period, method: method)
        }

        guard let lowestRSI = nextRSI(at: 0), targetRSI >= lowestRSI - 0.000_001 else {
            return nil
        }

        var lowerPrice = 0.0
        var upperPrice = max(latestClose * 2, 1)
        guard var upperRSI = nextRSI(at: upperPrice) else { return nil }

        // 100未満のRSIなら上限価格を広げることで必ず近づける。
        while upperRSI < targetRSI, upperPrice < 1_000_000_000_000 {
            upperPrice *= 2
            guard let value = nextRSI(at: upperPrice) else { return nil }
            upperRSI = value
        }
        guard upperRSI >= targetRSI else { return nil }

        // RSIは次の終値に対し単調増加するため、2分探索で逆算できる。
        for _ in 0..<100 {
            let middlePrice = (lowerPrice + upperPrice) / 2
            guard let middleRSI = nextRSI(at: middlePrice) else { return nil }
            if middleRSI < targetRSI {
                lowerPrice = middlePrice
            } else {
                upperPrice = middlePrice
            }
        }
        return (lowerPrice + upperPrice) / 2
    }

    private static func rsiValue(gains: Double, losses: Double) -> Double {
        let denominator = gains + losses
        guard denominator != 0 else { return 100 }
        return gains / denominator * 100
    }
}
