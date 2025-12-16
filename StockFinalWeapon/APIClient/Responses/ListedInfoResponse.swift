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
    let code: String
    let companyName: String
    let marketCode: String?
    
    private enum CodingKeys: String, CodingKey {
        case code = "Code"
        case companyName = "CompanyName"
        case marketCode = "MarketCode"
    }
}
