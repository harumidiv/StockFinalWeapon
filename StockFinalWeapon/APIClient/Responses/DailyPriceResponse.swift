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
    let Code: String
    let Date: String
    let Open: Double
    let High: Double
    let Low: Double
    let Close: Double
    let Volume: Double?
}
