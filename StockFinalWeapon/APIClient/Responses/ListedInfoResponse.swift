//
//  ListedInfoResponse.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

struct ListedInfoResponse: Decodable {
    let info: [ListedInfo]
}

struct ListedInfo: Decodable {
    let Code: String
    let CompanyName: String
    let MarketCode: String?
}
