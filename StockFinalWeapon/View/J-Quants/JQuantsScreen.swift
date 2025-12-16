//
//  JQuantsScreen.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//上場銘柄一覧（/listed/info）
//株価四本値*（/prices/daily_quotes）
//財務情報/fins/statements)

import SwiftUI
// ログインAPIのレスポンス
struct LoginResponse: Codable {
    let token: String
    let refreshToken: String
    let tokenExpiration: String
}

// 共通のエラーレスポンス（APIによって異なる場合があります）
struct APIErrorResponse: Codable {
    let message: String
}

// 認証情報
struct Credentials: Encodable {
    let mailaddress: String
    let password: String
}

//struct RefreshTokenResponse: Decodable {
//    let refreshToken: String
//}

struct IdTokenResponse: Decodable {
    let idToken: String
}

struct JQuantsScreen: View {
    let apiClient = APIClient()

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .task {
                let email = "harumi.hobby@gmail.com"
                let password = "A7kL9mQ2R8sT"
                
                Task {
                    do {
                        
                        let authClient = AuthClient(client: apiClient)
                        let refreshToken = try await authClient.fetchRefreshToken(mail: email, password: password)
                        
//                        let refreshToken = try await fetchRefreshToken(mail: email, password: password)
                        let idToken = try await fetchIdToken(refreshToken: refreshToken)
                        let stockList = try await fetchListedInfo(idToken: idToken)
                        
                        let finance = try await fetchFinancialStatements(idToken: idToken, code: stockList[0].Code)
                        
                        let fcf = Int(finance[0].CashFlowsFromOperatingActivities ?? "0")! - Int(finance[0].CashFlowsFromInvestingActivities ?? "0")!
                        let marketCap = Int(finance[0].NetSales ?? "0")! / fcf * 100
                        print("🐈: \(marketCap)")
                    } catch {
                        print("エラーが発生しました: \(error.localizedDescription)")
                    }
                }
            }
    }
    
    // 例: 個別銘柄情報のレスポンスモデル
    struct StockResponse: Codable {
        let code: String
        let name: String
        // ... 他のフィールド
    }
    
    func fetchStockData(token: String, date: String, code: String) async throws -> [StockResponse] {
        // データ取得APIのURL (実際のURLに置き換えてください)
        // 例: https://api.j-quants.com/v1/listed/daily_prices?date=20230101&code=99840
        var urlComponents = URLComponents(string: "https://api.j-quants.com/v1/listed/daily_prices")!
        urlComponents.queryItems = [
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "code", value: code)
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // 認証ヘッダーにトークンを設定
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            // 成功: データをデコード
            // J-Quants APIの多くは、データを配列を含むトップレベルのキー（例: 'daily_prices'）で返します
            // この例では、APIレスポンスの形に合わせて、デコード処理を調整してください。
            // 例として、トップレベルが配列だと仮定して直接デコードします。
            let stockData = try JSONDecoder().decode([StockResponse].self, from: data)
            return stockData
        } else {
            // 失敗
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw NSError(domain: "JQuantsAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse?.message ?? "データ取得失敗"])
        }
    }
}

struct ListedInfoResponse: Decodable {
    let info: [ListedInfo]
}

struct ListedInfo: Decodable {
    let Code: String
    let CompanyName: String
    let MarketCode: String?
}

struct FinancialStatementsResponse: Decodable {
    let statements: [FinancialStatement]
}

struct FinancialStatement: Codable {
    // 日付・期間情報
    let DisclosedDate: String?
    let DisclosedTime: String?
    let LocalCode: String?
    let DisclosureNumber: String?
    let TypeOfDocument: String?
    let TypeOfCurrentPeriod: String?
    let CurrentPeriodStartDate: String?
    let CurrentPeriodEndDate: String?
    let CurrentFiscalYearStartDate: String?
    let CurrentFiscalYearEndDate: String?
    let NextFiscalYearStartDate: String?
    let NextFiscalYearEndDate: String?
    
    // 実績値 (Current Period Results)
    let NetSales: String?
    let OperatingProfit: String?
    let OrdinaryProfit: String?
    let Profit: String?
    let EarningsPerShare: String?
    let DilutedEarningsPerShare: String?
    let TotalAssets: String?
    let Equity: String?
    let EquityToAssetRatio: String?
    let BookValuePerShare: String?
    let CashFlowsFromOperatingActivities: String?
    let CashFlowsFromInvestingActivities: String?
    let CashFlowsFromFinancingActivities: String?
    let CashAndEquivalents: String?
    
    // 配当実績 (Result Dividend)
    let ResultDividendPerShare1stQuarter: String?
    let ResultDividendPerShare2ndQuarter: String?
    let ResultDividendPerShare3rdQuarter: String?
    let ResultDividendPerShareFiscalYearEnd: String?
    let ResultDividendPerShareAnnual: String?
    // JSONキー "DistributionsPerUnit(REIT)" に対応
    let DistributionsPerUnit_REIT: String?
    let ResultTotalDividendPaidAnnual: String?
    let ResultPayoutRatioAnnual: String?
    
    // 配当予想 (Forecast Dividend)
    let ForecastDividendPerShare1stQuarter: String?
    let ForecastDividendPerShare2ndQuarter: String?
    let ForecastDividendPerShare3rdQuarter: String?
    let ForecastDividendPerShareFiscalYearEnd: String?
    let ForecastDividendPerShareAnnual: String?
    // JSONキー "ForecastDistributionsPerUnit(REIT)" に対応
    let ForecastDistributionsPerUnit_REIT: String?
    let ForecastTotalDividendPaidAnnual: String?
    let ForecastPayoutRatioAnnual: String?
    
    // 翌年配当予想 (Next Year Forecast Dividend)
    let NextYearForecastDividendPerShare1stQuarter: String?
    let NextYearForecastDividendPerShare2ndQuarter: String?
    let NextYearForecastDividendPerShare3rdQuarter: String?
    let NextYearForecastDividendPerShareFiscalYearEnd: String?
    let NextYearForecastDividendPerShareAnnual: String?
    // JSONキー "NextYearForecastDistributionsPerUnit(REIT)" に対応
    let NextYearForecastDistributionsPerUnit_REIT: String?
    let NextYearForecastPayoutRatioAnnual: String?
    
    // 業績予想 (Forecasts)
    let ForecastNetSales2ndQuarter: String?
    let ForecastOperatingProfit2ndQuarter: String?
    let ForecastOrdinaryProfit2ndQuarter: String?
    let ForecastProfit2ndQuarter: String?
    let ForecastEarningsPerShare2ndQuarter: String?
    
    // 翌年業績予想 (Next Year Forecasts)
    let NextYearForecastNetSales2ndQuarter: String?
    let NextYearForecastOperatingProfit2ndQuarter: String?
    let NextYearForecastOrdinaryProfit2ndQuarter: String?
    let NextYearForecastProfit2ndQuarter: String?
    let NextYearForecastEarningsPerShare2ndQuarter: String?
    
    // 通期業績予想 (Full Year Forecasts)
    let ForecastNetSales: String?
    let ForecastOperatingProfit: String?
    let ForecastOrdinaryProfit: String?
    let ForecastProfit: String?
    let ForecastEarningsPerShare: String?
    
    // 翌年通期業績予想 (Next Year Full Year Forecasts)
    let NextYearForecastNetSales: String?
    let NextYearForecastOperatingProfit: String?
    let NextYearForecastOrdinaryProfit: String?
    let NextYearForecastProfit: String?
    let NextYearForecastEarningsPerShare: String?
    
    // 会計情報 (Accounting Info)
    let MaterialChangesInSubsidiaries: String?
    let SignificantChangesInTheScopeOfConsolidation: String?
    let ChangesBasedOnRevisionsOfAccountingStandard: String?
    let ChangesOtherThanOnesBasedOnRevisionsOfAccountingStandard: String?
    let ChangesInAccountingEstimates: String?
    let RetrospectiveRestatement: String?
    
    // 株式情報 (Share Info)
    let NumberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock: String?
    let NumberOfTreasuryStockAtTheEndOfFiscalYear: String?
    let AverageNumberOfShares: String?
    
    // 非連結情報 (Non-Consolidated Info)
    let NonConsolidatedNetSales: String?
    let NonConsolidatedOperatingProfit: String?
    let NonConsolidatedOrdinaryProfit: String?
    let NonConsolidatedProfit: String?
    let NonConsolidatedEarningsPerShare: String?
    let NonConsolidatedTotalAssets: String?
    let NonConsolidatedEquity: String?
    let NonConsolidatedEquityToAssetRatio: String?
    let NonConsolidatedBookValuePerShare: String?
    
    // 非連結業績予想 (Non-Consolidated Forecasts)
    let ForecastNonConsolidatedNetSales2ndQuarter: String?
    let ForecastNonConsolidatedOperatingProfit2ndQuarter: String?
    let ForecastNonConsolidatedOrdinaryProfit2ndQuarter: String?
    let ForecastNonConsolidatedProfit2ndQuarter: String?
    let ForecastNonConsolidatedEarningsPerShare2ndQuarter: String?
    
    // 翌年非連結業績予想 (Next Year Non-Consolidated Forecasts)
    let NextYearForecastNonConsolidatedNetSales2ndQuarter: String?
    let NextYearForecastNonConsolidatedOperatingProfit2ndQuarter: String?
    let NextYearForecastNonConsolidatedOrdinaryProfit2ndQuarter: String?
    let NextYearForecastNonConsolidatedProfit2ndQuarter: String?
    let NextYearForecastNonConsolidatedEarningsPerShare2ndQuarter: String?
    
    // 非連結通期予想 (Non-Consolidated Full Year Forecasts)
    let ForecastNonConsolidatedNetSales: String?
    let ForecastNonConsolidatedOperatingProfit: String?
    let ForecastNonConsolidatedOrdinaryProfit: String?
    let ForecastNonConsolidatedProfit: String?
    let ForecastNonConsolidatedEarningsPerShare: String?
    
    // 翌年非連結通期予想 (Next Year Non-Consolidated Full Year Forecasts)
    let NextYearForecastNonConsolidatedNetSales: String?
    let NextYearForecastNonConsolidatedOperatingProfit: String?
    let NextYearForecastNonConsolidatedOrdinaryProfit: String?
    let NextYearForecastNonConsolidatedProfit: String?
    let NextYearForecastNonConsolidatedEarningsPerShare: String?
}

// MARK: - API

extension JQuantsScreen {
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

#Preview {
    JQuantsScreen()
}
