//
//  APIClient.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//


import Foundation

// HTTP通信実行の中核を担う汎用クライアント
class APIClient {
    
    // すべてのAPIRequestを実行するための汎用メソッド
    func send<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        
        // 1. URLの構築
        var components = URLComponents(string: request.baseURL)!
        components.path = request.path
        
        if let params = request.queryParameters {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // 2. URLRequestの構築
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.httpBody
        
        // ヘッダーの付与
        let finalHeaders = request.headers ?? [:]
        // 認証を必要とするリクエストのAuthorizationヘッダーは、Request自体で付与される
        for (key, value) in finalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // 3. 実行とエラーハンドリング
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse(statusCode: -1, rawBody: nil)
        }
                
        if let rawBody = String(data: data, encoding: .utf8) {
            if (200...299).contains(httpResponse.statusCode) {
                print("✅ API Success (StatusCode: \(httpResponse.statusCode))")
//                print("➡️ Raw JSON Body:")
//                print(rawBody)
            } else {
                // 失敗時のエラー出力 (既存のコード)
                print("❌ StatusCode: \(httpResponse.statusCode), Raw Body: \(rawBody)")
                throw NetworkError.badResponse(statusCode: httpResponse.statusCode, rawBody: rawBody)
            }
        }
        
        
        // 4. レスポンスのデコード
        do {
            let decodedResponse = try JSONDecoder().decode(Request.Response.self, from: data)
            return decodedResponse
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
