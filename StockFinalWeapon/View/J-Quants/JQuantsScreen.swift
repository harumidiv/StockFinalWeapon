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
                        let stockFilterList = filterOutETFs(listedInfo: stockList)
//                        let finance = try await stockClient.fetchFinancialStatements(idToken: idToken, code: "372A")
                        
//                        let price = try await stockClient.fetchDailyPrices(idToken: idToken, code: "372A")
                        
                        
                        print(stockFilterList.count)
//                        print("a: \(price.last!.close)")
                        
//                        guard let financeData = finance.first, let priceData = price.last else {
//                            return
//                        }
                        
//                        let fcf = Double(financeData.cashFlowsFromOperatingActivities)! + Double(financeData.cashFlowsFromInvestingActivities)!
//                        let marketCap = Double(financeData.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock)! * priceData.close
//                        print("🐈: \(fcf / marketCap * 100)")
                    } catch {
                        print("エラーが発生しました: \(error.localizedDescription)")
                    }
                }
            }
    }
    
    private func filterOutETFs(listedInfo: [ListedInfo]) -> [ListedInfo] {
        
        let businessStocks = listedInfo.filter { info in
            
            // 1. 17業種コードが「99」（その他）でない
            let isNotSector99 = info.sector17Code != "99"
            
            // 2. 33業種コードが「9999」（その他）でない
            //    (ETFの場合、このフィールドがないか、9999になることが多い)
            let isNotSector9999 = info.sector33Code != "9999"
            
            // 3. 市場名が「その他」ではない（補助的なフィルタリング）
            //    現物株のみに絞る場合は追加でチェックすると良い
            let isNotMarketOther = info.marketCodeName != "その他"
            
            // 株式（事業会社）と見なす条件: 17業種コードが99ではない、かつ 33業種コードが9999ではない
            return isNotSector99 && isNotSector9999
        }
        
        return businessStocks
    }
}

#Preview {
    JQuantsScreen()
}
