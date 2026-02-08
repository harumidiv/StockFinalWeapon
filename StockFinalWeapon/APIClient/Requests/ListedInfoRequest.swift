//
//  ListedInfoRequest.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

struct ListedInfoRequest: APIRequest {
    typealias Response = ListedInfoResponse
    
    let idToken: String

    var baseURL: String { return "https://api.jquants.com" }
    var path: String { return "/v1/listed/info" }
    var method: HTTPMethod { return .get }
    
    var headers: [String: String]? {
        return ["Authorization": "Bearer \(idToken)"]
    }
}
