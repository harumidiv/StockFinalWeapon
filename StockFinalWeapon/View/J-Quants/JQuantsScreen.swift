//
//  JQuantsScreen.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.

import SwiftUI

struct FCFStockInfo: Identifiable {
    let id = UUID()
    let stock: ListedInfo
    let financials: FinancialStatement
    let fcfYield: Double
    let closingPrice: Double
}

struct JQuantsScreen: View {
    let apiClient = APIClient()
    @State private var highFCFList: [FCFStockInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("銘柄データを取得中...")
                            .foregroundColor(.secondary)
                    }
                } else if let errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("エラー")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if highFCFList.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("FCF利回り10%超の銘柄が見つかりませんでした")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(highFCFList) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.stock.code)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("\(String(format: "%.2f", item.fcfYield))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(fcfYieldColor(item.fcfYield))
                            }
                            
                            Text(item.stock.companyName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Label("\(String(format: "%.0f", item.closingPrice))円", systemImage: "yensign.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("・")
                                    .foregroundColor(.secondary)
                                Text(item.stock.sector33CodeName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("高FCF利回り銘柄")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(highFCFList.count)銘柄")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            isLoading = true
            errorMessage = nil
            
            let email = "harumi.hobby@gmail.com"
            let password = "A7kL9mQ2R8sT"
            
            do {
                let authClient = AuthClient(client: apiClient)
                let stockClient = StockClient(client: apiClient)
                
                let refreshToken = try await authClient.fetchRefreshToken(mail: email, password: password)
                let idToken = try await authClient.fetchIdToken(refreshToken: refreshToken)
                
                let stockList = try await stockClient.fetchListedInfo(idToken: idToken)
                let stockFilterList = filterOutETFs(listedInfo: stockList)
                
                var tempHighFCFList: [FCFStockInfo] = []
                
                for stock in stockFilterList {
                    let code = stock.code
                    let name = stock.companyName
                    
                    // 銘柄コード、財務情報、株価データを並列取得
                    let (financeResult, priceResult) = try await (
                        stockClient.fetchFinancialStatements(idToken: idToken, code: code),
                        stockClient.fetchDailyPrices(idToken: idToken, code: code)
                    )
                    
                    // 最新の財務データと株価データを安全に取得
                    guard let financeResult,
                          let priceData = priceResult.last else {
                        // 財務データまたは株価データがない場合はスキップ
                        print("--- \(code) \(name): ⚠️ 必要なデータが見つかりませんでした。スキップします。")
                        continue
                    }
                    
                    guard let financeData = financeResult
                        .reversed()
                        .first(where: {
                            toDouble($0.cashFlowsFromOperatingActivities) != nil &&
                            toDouble($0.cashFlowsFromInvestingActivities) != nil &&
                            toDouble($0.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock) != nil &&
                            toDouble($0.numberOfTreasuryStockAtTheEndOfFiscalYear) != nil
                        }) else {
                        
                        print("--- \(code) \(name): ⚠️ CFが入っている財務データが見つかりません")
                        continue
                    }
                    
                    
                    // 4. FCF利回り計算に必要なデータの安全な数値変換
                    
                    // 営業CF + 投資CF
                    guard let operatingCF = Double(financeData.cashFlowsFromOperatingActivities ?? ""),
                          let investingCF = Double(financeData.cashFlowsFromInvestingActivities ?? "") else {
                        print("--- \(code) \(name): ⚠️ キャッシュフロー値の変換に失敗しました。スキップします。")
                        continue
                    }
                    
                    // 発行済株式総数 - 自己株式数 = 流通株式数
                    guard let issuedShares = Double(financeData.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock ?? ""),
                          let treasuryShares = Double(financeData.numberOfTreasuryStockAtTheEndOfFiscalYear ?? "") else {
                        print("--- \(code) \(name): ⚠️ 株式数データの変換に失敗しました。スキップします。")
                        continue
                    }
                    
                    // 5. FCF利回りの計算
                    
                    let fcf = operatingCF + investingCF
                    let outstandingShares = issuedShares - treasuryShares
                    if outstandingShares <= 0 {
                        continue
                    }
                    
                    // 終値
                    let closingPrice = priceData.close // Double型と仮定
                    // 時価総額 = 流通株式数 × 株価
                    let marketCap = outstandingShares * (closingPrice ?? 0)
                    
                    // FCF利回り = (FCF / 時価総額) × 100
                    let fcfYield = (fcf / marketCap) * 100
                    print("--- \(code) \(name): 💰 FCF利回り: \(String(format: "%.2f", fcfYield))%")
                    
                    if fcfYield > 10.0 {
                        tempHighFCFList.append(.init(
                            stock: stock,
                            financials: financeData,
                            fcfYield: fcfYield,
                            closingPrice: closingPrice ?? 0
                        ))
                    }
                }
                
                // FCF利回りの高い順にソート
                highFCFList = tempHighFCFList.sorted { $0.fcfYield > $1.fcfYield }
                isLoading = false
                
                print("高FCF利回り銘柄: \(highFCFList.count)件")
                
                
                // 📝 編集前のコード
                //
                //                    let finance = try await stockClient.fetchFinancialStatements(idToken: idToken, code: "1380")
                //                    let price = try await stockClient.fetchDailyPrices(idToken: idToken, code: "1380")
                
                
                //                    print("a: \(price.last!.close)")
                //
                //                    guard let finance, let financeData = finance.first, let priceData = price.last else {
                //                        return
                //                    }
                //
                //                    let fcf = Double(financeData.cashFlowsFromOperatingActivities ?? "")! + Double(financeData.cashFlowsFromInvestingActivities ?? "")!
                //                    let marketCap = Double(financeData.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock ?? "")! * priceData.close
                //                    print("🐈: \(fcf / marketCap * 100)")
            } catch {
                print("エラーが発生しました: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func fcfYieldColor(_ yield: Double) -> Color {
        if yield >= 20.0 {
            return .green
        } else if yield >= 15.0 {
            return .blue
        } else {
            return .orange
        }
    }
    
    func toDouble(_ value: String?) -> Double? {
        guard let value = value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value != "-",
              value != "－" else {
            return nil
        }
        return Double(value)
    }
    
    private func filterOutETFs(listedInfo: [ListedInfo]) -> [ListedInfo] {
        
        let businessStocks = listedInfo.filter { info in
            
            // 1. 17業種コードが「99」（その他）でない
            let isNotSector99 = info.sector17Code != "99"
            
            // 2. TOKYO PRO Market (TPM) の除外 (★新しいフィルタリング★)
            // MarketCode: "プライム、スタンダード、グロース" 意外を除外する
            let isNotTPM = info.marketCode == "0111" || info.marketCode == "0112" || info.marketCode == "0113"
            
            // 2. 33業種コードが「9999」（その他）でない
            //    (ETFの場合、このフィールドがないか、9999になることが多い)
            let isNotSector9999 = info.sector33Code != "9999"
            
            // 現物株式（事業会社）かつ、主要市場に上場している銘柄
            return isNotSector99 && isNotTPM && isNotSector9999
        }
        
        return businessStocks
    }
}

#Preview {
    JQuantsScreen()
}
