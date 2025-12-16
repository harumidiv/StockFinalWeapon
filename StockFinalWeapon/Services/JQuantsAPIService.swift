//
//  JQuantsAPIService.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

struct JQuantsAPIService {
    func fetchFinancialStatements(
        idToken: String,
        code: String
    ) async throws -> [FinancialStatement] {
        
        var components = URLComponents(
            string: "https://api.jquants.com/v1/fins/statements"
        )!
        components.queryItems = [
            URLQueryItem(name: "code", value: code)
        ]
        
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse {
            print("StatusCode:", http.statusCode)
        }
        print("Raw:", String(data: data, encoding: .utf8) ?? "")
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(
                domain: "JQuants",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        String(data: data, encoding: .utf8) ?? ""
                ]
            )
        }
        
        return try JSONDecoder()
            .decode(FinancialStatementsResponse.self, from: data)
            .statements
    }
    
    
    func fetchListedInfo(idToken: String) async throws -> [ListedInfo] {
        
        let url = URL(string: "https://api.jquants.com/v1/listed/info")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 🔑 idTokenをBearerで指定
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        
        return try JSONDecoder()
            .decode(ListedInfoResponse.self, from: data)
            .info
    }
    
    
    func fetchRefreshToken(
        mail: String,
        password: String
    ) async throws -> String {
        
        let url = URL(string: "https://api.jquants.com/v1/token/auth_user")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "mailaddress": mail,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
        return response.refreshToken
    }
    
    
    func fetchIdToken(refreshToken: String) async throws -> String {
        var components = URLComponents(string: "https://api.jquants.com/v1/token/auth_refresh")!
        components.queryItems = [
            URLQueryItem(name: "refreshtoken", value: refreshToken)
        ]
        
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(IdTokenResponse.self, from: data)
        return response.idToken
    }
}
