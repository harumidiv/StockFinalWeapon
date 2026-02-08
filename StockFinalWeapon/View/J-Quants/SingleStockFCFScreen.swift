//
//  SingleStockFCFScreen.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2026/02/08.
//

import SwiftUI
import UIKit

struct SingleStockFCFScreen: View {
    let stockCode: String

    let apiClient = APIClient()
    @State private var fcfInfo: FCFStockInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("データを取得中...")
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
            } else if let fcfInfo {
                ScrollView {
                    VStack(spacing: 24) {
                        // FCF利回り表示
                        VStack(spacing: 8) {
                            Text("FCF利回り")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.2f", fcfInfo.fcfYield))%")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(fcfYieldColor(fcfInfo.fcfYield))
                        }
                        .padding(.top, 32)

                        Divider()

                        // 銘柄情報
                        VStack(spacing: 16) {
                            InfoRow(label: "銘柄コード", value: fcfInfo.stock.code)
                            InfoRow(label: "銘柄名", value: fcfInfo.stock.companyName)
                            InfoRow(label: "業種", value: fcfInfo.stock.sector33CodeName)
                            InfoRow(label: "開示日", value: fcfInfo.formattedDisclosedDate)
                            InfoRow(label: "株価", value: "\(String(format: "%.0f", fcfInfo.closingPrice))円")
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("データが見つかりませんでした")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("銘柄コード: \(stockCode)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFCFData()
        }
    }

    private func loadFCFData() async {
        isLoading = true
        errorMessage = nil

        // 画面スリープを無効化
        UIApplication.shared.isIdleTimerDisabled = true

        let email = "harumi.hobby@gmail.com"
        let password = "A7kL9mQ2R8sT"

        do {
            let authClient = AuthClient(client: apiClient)
            let stockClient = StockClient(client: apiClient)

            let refreshToken = try await authClient.fetchRefreshToken(mail: email, password: password)
            let idToken = try await authClient.fetchIdToken(refreshToken: refreshToken)

            // 銘柄情報を取得
            let stockList = try await stockClient.fetchListedInfo(idToken: idToken)

            guard let stock = stockList.first(where: { $0.code == stockCode }) else {
                errorMessage = "銘柄コード \(stockCode) が見つかりません"
                isLoading = false
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }

            // 財務情報と株価データを取得
            let (financeResult, priceResult) = try await (
                stockClient.fetchFinancialStatements(idToken: idToken, code: stockCode),
                stockClient.fetchDailyPrices(idToken: idToken, code: stockCode)
            )

            // 財務データの取得確認
            guard let financeResult else {
                errorMessage = "財務データが見つかりません"
                isLoading = false
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }

            // CFデータが揃っている最新の財務データを取得
            guard let financeData = financeResult
                .reversed()
                .first(where: {
                    toDouble($0.cashFlowsFromOperatingActivities) != nil &&
                    toDouble($0.cashFlowsFromInvestingActivities) != nil &&
                    toDouble($0.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock) != nil
                }) else {
                errorMessage = "キャッシュフローデータが見つかりません"
                isLoading = false
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }

            // 財務データの開示日を取得
            guard let disclosedDate = financeData.disclosedDate else {
                errorMessage = "開示日が見つかりません"
                isLoading = false
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }

            // 開示日と同じ日付の株価データを取得
            guard let priceData = priceResult.first(where: { $0.date == disclosedDate }) else {
                errorMessage = "開示日(\(disclosedDate))の株価データが見つかりません"
                isLoading = false
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }

            // FCF利回り計算
            guard let operatingCF = Double(financeData.cashFlowsFromOperatingActivities ?? ""),
                  let investingCF = Double(financeData.cashFlowsFromInvestingActivities ?? ""),
                  let issuedShares = Double(financeData.numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock ?? ""),
                  let closingPrice = priceData.close else {
                errorMessage = "データの変換に失敗しました"
                isLoading = false
                UIApplication.shared.isIdleTimerDisabled = false
                return
            }

            let fcf = operatingCF + investingCF
            let marketCap = issuedShares * closingPrice
            let fcfYield = (fcf / marketCap) * 100

            fcfInfo = FCFStockInfo(
                stock: stock,
                financials: financeData,
                fcfYield: fcfYield,
                closingPrice: closingPrice,
                disclosedDate: disclosedDate
            )

            isLoading = false
            UIApplication.shared.isIdleTimerDisabled = false

        } catch {
            print("エラーが発生しました: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func fcfYieldColor(_ yield: Double) -> Color {
        if yield >= 20.0 {
            return .green
        } else if yield >= 15.0 {
            return .blue
        } else if yield >= 8.0 {
            return .orange
        } else {
            return .red
        }
    }

    private func toDouble(_ value: String?) -> Double? {
        guard let value = value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value != "-",
              value != "－" else {
            return nil
        }
        return Double(value)
    }
}

// 情報行表示用のヘルパービュー
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SingleStockFCFScreen(stockCode: "7203")
    }
}
