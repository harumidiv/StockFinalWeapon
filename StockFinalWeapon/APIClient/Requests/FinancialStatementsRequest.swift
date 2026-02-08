//
//  FinancialStatementsRequest.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

// MARK: - FinancialStatementsRequest
// J-Quants 財務諸表 API: GET /v1/fins/statements
// クエリ: code(必須), date / from / to(任意), pagination_key(任意)
struct FinancialStatementsRequest: APIRequest {
    typealias Response = FinancialStatementsResponse
    
    let idToken: String
    let code: String
    let date: String?
    let from: String?
    let to: String?
    let paginationKey: String?
    
    init(
        idToken: String,
        code: String,
        date: String? = nil,
        from: String? = nil,
        to: String? = nil,
        paginationKey: String? = nil
    ) {
        self.idToken = idToken
        self.code = code
        self.date = date
        self.from = from
        self.to = to
        self.paginationKey = paginationKey
    }

    var baseURL: String { return "https://api.jquants.com" }
    var path: String { return "/v1/fins/statements" }
    var method: HTTPMethod { return .get }
    
    var queryParameters: [String: String]? {
        var params: [String: String] = ["code": code]
        if let date { params["date"] = date }
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        if let paginationKey { params["pagination_key"] = paginationKey }
        return params
    }
    
    var headers: [String: String]? {
        // 認証ヘッダーをリクエスト定義自体に持たせる
        return ["Authorization": "Bearer \(idToken)"]
    }
}
