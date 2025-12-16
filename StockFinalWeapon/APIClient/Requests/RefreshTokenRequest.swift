//
//  RefreshTokenRequest.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

// MARK: - RefreshTokenRequest (メールとパスワードでリフレッシュトークンを取得)
struct RefreshTokenRequest: APIRequest, Decodable {
    typealias Response = RefreshTokenResponse
    
    let mail: String
    let password: String
    
    init(mail: String, password: String) {
        self.mail = mail
        self.password = password
    }

    var baseURL: String { "https://api.jquants.com" }
    var path: String { "/v1/token/auth_user" }
    var method: HTTPMethod { .post }

    var httpBody: Data? {
        let body: [String: String] = ["mailaddress": mail, "password": password]
        return try? JSONSerialization.data(withJSONObject: body)
    }
    
    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}
