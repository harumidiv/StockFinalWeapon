//
//  StockClient.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//


class StockClient {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }
    
    func fetchListedInfo(idToken: String) async throws -> [ListedInfo] {
        let request = ListedInfoRequest(idToken: idToken)
        let response = try await client.send(request)
        return response.info
    }
    
    func fetchFinancialStatements(idToken: String, code: String) async throws -> [FinancialStatement] {
        let request = FinancialStatementsRequest(idToken: idToken, code: code)
        let response = try await client.send(request)
        return response.statements
    }
}
