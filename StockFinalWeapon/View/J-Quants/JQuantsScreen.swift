//
//  JQuantsScreen.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.

import SwiftUI

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
                        let stockClient = StockClient(client: apiClient)
                        
                        let refreshToken = try await authClient.fetchRefreshToken(mail: email, password: password)
                        let idToken = try await authClient.fetchIdToken(refreshToken: refreshToken)
                        let stockList = try await stockClient.fetchListedInfo(idToken: idToken)
                        let finance = try await stockClient.fetchFinancialStatements(idToken: idToken, code: "372A")
                        
                        let price = try await stockClient.fetchDailyPrices(idToken: idToken, code: "372A")
                        
                        print("a: \(price.last!.close)")
                        
                        guard let financeData = finance.first, let priceData = price.last else {
                            return
                        }
                        
                        let fcf = Double(financeData.cashFlowsFromOperatingActivities)! + Double(financeData.cashFlowsFromInvestingActivities)!
                        let marketCap = Double(financeData.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock)! * priceData.close
                        print("🐈: \(fcf / marketCap * 100)")
                    } catch {
                        print("エラーが発生しました: \(error.localizedDescription)")
                    }
                }
            }
    }
}

#Preview {
    JQuantsScreen()
}
