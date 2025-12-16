//
//  DailyPriceResponse.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

struct DailyPriceResponse: Decodable {
    let daily_quotes: [DailyQuote]
}

struct DailyQuote: Decodable {
    let code: String
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    
    private enum CodingKeys: String, CodingKey {
        // Swiftプロパティ名: JSONキー名
        case code = "Code"
        case date = "Date"
        case open = "Open"
        case high = "High"
        case low = "Low"
        case close = "Close"
        case volume = "Volume"
    }
}
