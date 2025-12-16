//
//  DailyPricesRequest.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

struct DailyPricesRequest: APIRequest {
    typealias Response = DailyPriceResponse

    let idToken: String
    let code: String
    var baseURL: String { return "https://api.jquants.com" }
    var path: String { return "/v1/prices/daily_quotes" }
    var method: HTTPMethod { return .get }
    
    var queryParameters: [String: String]? {
        return [
            "code": code,
        ]
    }
    
    var headers: [String: String]? {
        // 認証ヘッダーをリクエスト定義自体に持たせる
        return ["Authorization": "Bearer \(idToken)"]
    }
}
