//
//  IdTokenRequest.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

struct IdTokenRequest: APIRequest {
    typealias Response = IdTokenResponse
    
    let refreshToken: String

    var baseURL: String { return "https://api.jquants.com" }
    var path: String { return "/v1/token/auth_refresh" }
    var method: HTTPMethod { return .post }
    
    var queryParameters: [String: String]? {
        return ["refreshtoken": refreshToken]
    }
}
