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
    let date: String
    let code: String
    let companyName: String
    let companyNameEnglish: String
    let sector17Code: String
    let sector17CodeName: String
    let sector33Code: String
    let sector33CodeName: String
    let scaleCategory: String
    let marketCode: String
    let marketCodeName: String
    
    private enum CodingKeys: String, CodingKey {
        case date = "Date"
        case code = "Code"
        case companyName = "CompanyName"
        case companyNameEnglish = "CompanyNameEnglish"
        case sector17Code = "Sector17Code"
        case sector17CodeName = "Sector17CodeName"
        case sector33Code = "Sector33Code"
        case sector33CodeName = "Sector33CodeName"
        case scaleCategory = "ScaleCategory"
        case marketCode = "MarketCode"
        case marketCodeName = "MarketCodeName"
    }
}
