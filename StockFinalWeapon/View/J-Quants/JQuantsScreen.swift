//
//  JQuantsScreen.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.

import SwiftUI
import UIKit

struct FCFStockInfo: Identifiable {
    let id = UUID()
    let stock: ListedInfo
    let financials: FinancialStatement
    let fcfYield: Double
    let closingPrice: Double
    let disclosedDate: String

    // 開示日をyyyy/MM/dd形式にフォーマット
    var formattedDisclosedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let date = formatter.date(from: disclosedDate) {
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
        return disclosedDate
    }
}

struct JQuantsScreen: View {
    let selectedSector: Sector33

    let apiClient = APIClient()
    @State private var highFCFList: [FCFStockInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
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
                        Text("FCF利回り8%以上の銘柄が見つかりませんでした")
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
                                        Label(item.formattedDisclosedDate, systemImage: "calendar")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text("・")
                                            .foregroundColor(.secondary)

                                        Label("\(String(format: "%.0f", item.closingPrice))円", systemImage: "yensign.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
        }
        .navigationTitle(selectedSector.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(highFCFList.count)銘柄")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            isLoading = true
            errorMessage = nil

            // 画面スリープを無効化（長時間通信のため）
            UIApplication.shared.isIdleTimerDisabled = true

            let email = "harumi.hobby@gmail.com"
            let password = "A7kL9mQ2R8sT"

            do {
                let authClient = AuthClient(client: apiClient)
                let stockClient = StockClient(client: apiClient)
                
                let refreshToken = try await authClient.fetchRefreshToken(mail: email, password: password)
                let idToken = try await authClient.fetchIdToken(refreshToken: refreshToken)
                
                let stockList = try await stockClient.fetchListedInfo(idToken: idToken)

                // 選択した業種でフィルタリング
                let filteredStocks = stockList.filter { stock in
                    stock.sector33Code == selectedSector.code &&
                    stock.sector17Code != "99" &&
                    (stock.marketCode == "0111" || stock.marketCode == "0112" || stock.marketCode == "0113")
                }

                print("選択業種: \(selectedSector.name) (\(selectedSector.code))")
                print("フィルタ後銘柄数: \(filteredStocks.count)")

                var tempHighFCFList: [FCFStockInfo] = []

                for stock in filteredStocks {
                    let code = stock.code
                    let name = stock.companyName
                    
                    // 銘柄コード、財務情報、株価データを並列取得
                    let (financeResult, priceResult) = try await (
                        stockClient.fetchFinancialStatements(idToken: idToken, code: code),
                        stockClient.fetchDailyPrices(idToken: idToken, code: code)
                    )

                    // 財務データの取得確認
                    guard let financeResult else {
                        print("--- \(code) \(name): ⚠️ 財務データが見つかりませんでした。スキップします。")
                        continue
                    }

                    // CFデータが揃っている最新の財務データを取得
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

                    // 財務データの開示日を取得
                    guard let disclosedDate = financeData.disclosedDate else {
                        print("--- \(code) \(name): ⚠️ 開示日が見つかりません")
                        continue
                    }

                    // 開示日と同じ日付の株価データを取得
                    guard let priceData = priceResult.first(where: { $0.date == disclosedDate }) else {
                        print("--- \(code) \(name): ⚠️ 開示日(\(disclosedDate))の株価データが見つかりません。スキップします。")
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
                    guard let issuedShares = Double(financeData.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock ?? "") else {
                        print("--- \(code) \(name): ⚠️ 株式数データの変換に失敗しました。スキップします。")
                        continue
                    }
                    
                    // 5. FCF利回りの計算
                    
                    let fcf = operatingCF + investingCF
                    
                    // 終値
                    let closingPrice = priceData.close // Double型と仮定
                    // 時価総額 = 発行済株式総数 × 株価
                    let marketCap = issuedShares * (closingPrice ?? 0)
                    
                    // FCF利回り = (FCF / 時価総額) × 100
                    let fcfYield = (fcf / marketCap) * 100
                    print("--- \(code) \(name): 💰 FCF利回り: \(String(format: "%.2f", fcfYield))% (開示日: \(disclosedDate), 株価: \(closingPrice ?? 0)円)")
                    
                    // FIXME: ここで正しい値に絞り込む
                    if fcfYield >= 0 {
                        tempHighFCFList.append(.init(
                            stock: stock,
                            financials: financeData,
                            fcfYield: fcfYield,
                            closingPrice: closingPrice ?? 0,
                            disclosedDate: disclosedDate
                        ))
                    }
                }
                
                // FCF利回りの高い順にソート
                highFCFList = tempHighFCFList.sorted { $0.fcfYield > $1.fcfYield }
                isLoading = false

                // 画面スリープを再度有効化
                UIApplication.shared.isIdleTimerDisabled = false

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

                // エラー時も画面スリープを再度有効化
                UIApplication.shared.isIdleTimerDisabled = false
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
    JQuantsScreen(selectedSector: Sector33(code: "0050", name: "水産・農林業"))
}
