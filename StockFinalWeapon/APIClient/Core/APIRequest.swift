//
//  APIRequest.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

// すべてのAPIリクエストが準拠すべきプロトコル
protocol APIRequest {
    associatedtype Response: Decodable
    
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var queryParameters: [String: String]? { get }
    var httpBody: Data? { get } // プロトコル要件として定義
    var headers: [String: String]? { get } // プロトコル要件として定義
}

extension APIRequest {
    // GETリクエストの場合はボディはnil
    var httpBody: Data? { return nil }
    // 通常のGETリクエストにはカスタムヘッダーは不要
    var headers: [String: String]? { return nil }
    // GET/POSTに関わらずクエリパラメータが不要な場合もある
    var queryParameters: [String: String]? { return nil }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

enum NetworkError: Error {
    case invalidURL
    case badResponse(statusCode: Int, rawBody: String?)
    case decodingError(Error)
}
