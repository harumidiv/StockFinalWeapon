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
    
    
    /// 東証銘柄リスト
    /// - Parameter idToken: idToken
    /// - Returns: 銘柄情報のリスト
    func fetchListedInfo(idToken: String) async throws -> [ListedInfo] {
        let request = ListedInfoRequest(idToken: idToken)
        let response = try await client.send(request)
        return response.info
    }
    
    /// 四季報の財務情報
    /// - Parameters:
    ///   - idToken: idToken
    ///   - code: 銘柄コード
    /// - Returns: 財務情報
    func fetchFinancialStatements(idToken: String, code: String) async throws -> [FinancialStatement]? {
        let request = FinancialStatementsRequest(idToken: idToken, code: code)
        let response = try await client.send(request)
        return response.statements
    }

    /// 株価情報を取得
    /// - Parameters:
    ///   - idToken: idToken
    ///   - code: 銘柄コード
    /// - Returns: 株価データ
    func fetchDailyPrices(
        idToken: String,
        code: String,
    ) async throws -> [DailyQuote] {
        let request = DailyPricesRequest(idToken: idToken, code: code)
        let response = try await client.send(request)
        return response.daily_quotes
    }

}
