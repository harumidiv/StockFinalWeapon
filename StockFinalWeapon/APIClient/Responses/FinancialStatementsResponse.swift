//
//  FinancialStatementsResponse.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2025/12/16.
//

import Foundation

struct FinancialStatementsResponse: Decodable {
    let statements: [FinancialStatement]
}

struct FinancialStatement: Decodable {
    // 日付・期間情報
    let disclosedDate: String
    let disclosedTime: String
    let localCode: String
    let disclosureNumber: String
    let typeOfDocument: String
    let typeOfCurrentPeriod: String
    let currentPeriodStartDate: String
    let currentPeriodEndDate: String
    let currentFiscalYearStartDate: String
    let currentFiscalYearEndDate: String
    let nextFiscalYearStartDate: String
    let nextFiscalYearEndDate: String
    
    // 実績値 (Current Period Results)
    let netSales: String
    let operatingProfit: String
    let ordinaryProfit: String
    let profit: String
    let earningsPerShare: String
    let dilutedEarningsPerShare: String
    let totalAssets: String
    let equity: String
    let equityToAssetRatio: String
    let bookValuePerShare: String
    let cashFlowsFromOperatingActivities: String
    let cashFlowsFromInvestingActivities: String
    let cashFlowsFromFinancingActivities: String
    let cashAndEquivalents: String
    
    // 配当実績 (Result Dividend)
    let resultDividendPerShare1stQuarter: String
    let resultDividendPerShare2ndQuarter: String
    let resultDividendPerShare3rdQuarter: String
    let resultDividendPerShareFiscalYearEnd: String
    let resultDividendPerShareAnnual: String
    let distributionsPerUnit_REIT: String // JSON: DistributionsPerUnit(REIT)
    let resultTotalDividendPaidAnnual: String
    let resultPayoutRatioAnnual: String
    
    // 配当予想 (Forecast Dividend)
    let forecastDividendPerShare1stQuarter: String
    let forecastDividendPerShare2ndQuarter: String
    let forecastDividendPerShare3rdQuarter: String
    let forecastDividendPerShareFiscalYearEnd: String
    let forecastDividendPerShareAnnual: String
    let forecastDistributionsPerUnit_REIT: String // JSON: ForecastDistributionsPerUnit(REIT)
    let forecastTotalDividendPaidAnnual: String
    let forecastPayoutRatioAnnual: String
    
    // 翌年配当予想 (Next Year Forecast Dividend)
    let nextYearForecastDividendPerShare1stQuarter: String
    let nextYearForecastDividendPerShare2ndQuarter: String
    let nextYearForecastDividendPerShare3rdQuarter: String
    let nextYearForecastDividendPerShareFiscalYearEnd: String
    let nextYearForecastDividendPerShareAnnual: String
    let nextYearForecastDistributionsPerUnit_REIT: String // JSON: NextYearForecastDistributionsPerUnit(REIT)
    let nextYearForecastPayoutRatioAnnual: String
    
    // 業績予想 (Forecasts)
    let forecastNetSales2ndQuarter: String
    let forecastOperatingProfit2ndQuarter: String
    let forecastOrdinaryProfit2ndQuarter: String
    let forecastProfit2ndQuarter: String
    let forecastEarningsPerShare2ndQuarter: String
    
    // 翌年業績予想 (Next Year Forecasts)
    let nextYearForecastNetSales2ndQuarter: String
    let nextYearForecastOperatingProfit2ndQuarter: String
    let nextYearForecastOrdinaryProfit2ndQuarter: String
    let nextYearForecastProfit2ndQuarter: String
    let nextYearForecastEarningsPerShare2ndQuarter: String
    
    // 通期業績予想 (Full Year Forecasts)
    let forecastNetSales: String
    let forecastOperatingProfit: String
    let forecastOrdinaryProfit: String
    let forecastProfit: String
    let forecastEarningsPerShare: String
    
    // 翌年通期業績予想 (Next Year Full Year Forecasts)
    let nextYearForecastNetSales: String
    let nextYearForecastOperatingProfit: String
    let nextYearForecastOrdinaryProfit: String
    let nextYearForecastProfit: String
    let nextYearForecastEarningsPerShare: String
    
    // 会計情報 (Accounting Info)
    let materialChangesInSubsidiaries: String
    let significantChangesInTheScopeOfConsolidation: String
    let changesBasedOnRevisionsOfAccountingStandard: String
    let changesOtherThanOnesBasedOnRevisionsOfAccountingStandard: String
    let changesInAccountingEstimates: String
    let retrospectiveRestatement: String
    
    // 株式情報 (Share Info)
    let numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock: String
    let numberOfTreasuryStockAtTheEndOfFiscalYear: String
    let averageNumberOfShares: String
    
    // 非連結情報 (Non-Consolidated Info)
    let nonConsolidatedNetSales: String
    let nonConsolidatedOperatingProfit: String
    let nonConsolidatedOrdinaryProfit: String
    let nonConsolidatedProfit: String
    let nonConsolidatedEarningsPerShare: String
    let nonConsolidatedTotalAssets: String
    let nonConsolidatedEquity: String
    let nonConsolidatedEquityToAssetRatio: String
    let nonConsolidatedBookValuePerShare: String
    
    // 非連結業績予想 (Non-Consolidated Forecasts)
    let forecastNonConsolidatedNetSales2ndQuarter: String
    let forecastNonConsolidatedOperatingProfit2ndQuarter: String
    let forecastNonConsolidatedOrdinaryProfit2ndQuarter: String
    let forecastNonConsolidatedProfit2ndQuarter: String
    let forecastNonConsolidatedEarningsPerShare2ndQuarter: String
    
    // 翌年非連結業績予想 (Next Year Non-Consolidated Forecasts)
    let nextYearForecastNonConsolidatedNetSales2ndQuarter: String
    let nextYearForecastNonConsolidatedOperatingProfit2ndQuarter: String
    let nextYearForecastNonConsolidatedOrdinaryProfit2ndQuarter: String
    let nextYearForecastNonConsolidatedProfit2ndQuarter: String
    let nextYearForecastNonConsolidatedEarningsPerShare2ndQuarter: String
    
    // 非連結通期予想 (Non-Consolidated Full Year Forecasts)
    let forecastNonConsolidatedNetSales: String
    let forecastNonConsolidatedOperatingProfit: String
    let forecastNonConsolidatedOrdinaryProfit: String
    let forecastNonConsolidatedProfit: String
    let forecastNonConsolidatedEarningsPerShare: String
    
    // 翌年非連結通期予想 (Next Year Non-Consolidated Full Year Forecasts)
    let nextYearForecastNonConsolidatedNetSales: String
    let nextYearForecastNonConsolidatedOperatingProfit: String
    let nextYearForecastNonConsolidatedOrdinaryProfit: String
    let nextYearForecastNonConsolidatedProfit: String
    let nextYearForecastNonConsolidatedEarningsPerShare: String
    
    // MARK: - CodingKeys (マッピング定義)
    private enum CodingKeys: String, CodingKey {
        // 大文字始まりのキー
        case disclosedDate = "DisclosedDate"
        case disclosedTime = "DisclosedTime"
        case localCode = "LocalCode"
        case disclosureNumber = "DisclosureNumber"
        case typeOfDocument = "TypeOfDocument"
        case typeOfCurrentPeriod = "TypeOfCurrentPeriod"
        case currentPeriodStartDate = "CurrentPeriodStartDate"
        case currentPeriodEndDate = "CurrentPeriodEndDate"
        case currentFiscalYearStartDate = "CurrentFiscalYearStartDate"
        case currentFiscalYearEndDate = "CurrentFiscalYearEndDate"
        case nextFiscalYearStartDate = "NextFiscalYearStartDate"
        case nextFiscalYearEndDate = "NextFiscalYearEndDate"
        case netSales = "NetSales"
        case operatingProfit = "OperatingProfit"
        case ordinaryProfit = "OrdinaryProfit"
        case profit = "Profit"
        case earningsPerShare = "EarningsPerShare"
        case dilutedEarningsPerShare = "DilutedEarningsPerShare"
        case totalAssets = "TotalAssets"
        case equity = "Equity"
        case equityToAssetRatio = "EquityToAssetRatio"
        case bookValuePerShare = "BookValuePerShare"
        case cashFlowsFromOperatingActivities = "CashFlowsFromOperatingActivities"
        case cashFlowsFromInvestingActivities = "CashFlowsFromInvestingActivities"
        case cashFlowsFromFinancingActivities = "CashFlowsFromFinancingActivities"
        case cashAndEquivalents = "CashAndEquivalents"
        case resultDividendPerShare1stQuarter = "ResultDividendPerShare1stQuarter"
        case resultDividendPerShare2ndQuarter = "ResultDividendPerShare2ndQuarter"
        case resultDividendPerShare3rdQuarter = "ResultDividendPerShare3rdQuarter"
        case resultDividendPerShareFiscalYearEnd = "ResultDividendPerShareFiscalYearEnd"
        case resultDividendPerShareAnnual = "ResultDividendPerShareAnnual"
        // 特殊文字を含むキー
        case distributionsPerUnit_REIT = "DistributionsPerUnit(REIT)"
        case resultTotalDividendPaidAnnual = "ResultTotalDividendPaidAnnual"
        case resultPayoutRatioAnnual = "ResultPayoutRatioAnnual"
        case forecastDividendPerShare1stQuarter = "ForecastDividendPerShare1stQuarter"
        case forecastDividendPerShare2ndQuarter = "ForecastDividendPerShare2ndQuarter"
        case forecastDividendPerShare3rdQuarter = "ForecastDividendPerShare3rdQuarter"
        case forecastDividendPerShareFiscalYearEnd = "ForecastDividendPerShareFiscalYearEnd"
        case forecastDividendPerShareAnnual = "ForecastDividendPerShareAnnual"
        // 特殊文字を含むキー
        case forecastDistributionsPerUnit_REIT = "ForecastDistributionsPerUnit(REIT)"
        case forecastTotalDividendPaidAnnual = "ForecastTotalDividendPaidAnnual"
        case forecastPayoutRatioAnnual = "ForecastPayoutRatioAnnual"
        case nextYearForecastDividendPerShare1stQuarter = "NextYearForecastDividendPerShare1stQuarter"
        case nextYearForecastDividendPerShare2ndQuarter = "NextYearForecastDividendPerShare2ndQuarter"
        case nextYearForecastDividendPerShare3rdQuarter = "NextYearForecastDividendPerShare3rdQuarter"
        case nextYearForecastDividendPerShareFiscalYearEnd = "NextYearForecastDividendPerShareFiscalYearEnd"
        case nextYearForecastDividendPerShareAnnual = "NextYearForecastDividendPerShareAnnual"
        // 特殊文字を含むキー
        case nextYearForecastDistributionsPerUnit_REIT = "NextYearForecastDistributionsPerUnit(REIT)"
        case nextYearForecastPayoutRatioAnnual = "NextYearForecastPayoutRatioAnnual"
        case forecastNetSales2ndQuarter = "ForecastNetSales2ndQuarter"
        case forecastOperatingProfit2ndQuarter = "ForecastOperatingProfit2ndQuarter"
        case forecastOrdinaryProfit2ndQuarter = "ForecastOrdinaryProfit2ndQuarter"
        case forecastProfit2ndQuarter = "ForecastProfit2ndQuarter"
        case forecastEarningsPerShare2ndQuarter = "ForecastEarningsPerShare2ndQuarter"
        case nextYearForecastNetSales2ndQuarter = "NextYearForecastNetSales2ndQuarter"
        case nextYearForecastOperatingProfit2ndQuarter = "NextYearForecastOperatingProfit2ndQuarter"
        case nextYearForecastOrdinaryProfit2ndQuarter = "NextYearForecastOrdinaryProfit2ndQuarter"
        case nextYearForecastProfit2ndQuarter = "NextYearForecastProfit2ndQuarter"
        case nextYearForecastEarningsPerShare2ndQuarter = "NextYearForecastEarningsPerShare2ndQuarter"
        case forecastNetSales = "ForecastNetSales"
        case forecastOperatingProfit = "ForecastOperatingProfit"
        case forecastOrdinaryProfit = "ForecastOrdinaryProfit"
        case forecastProfit = "ForecastProfit"
        case forecastEarningsPerShare = "ForecastEarningsPerShare"
        case nextYearForecastNetSales = "NextYearForecastNetSales"
        case nextYearForecastOperatingProfit = "NextYearForecastOperatingProfit"
        case nextYearForecastOrdinaryProfit = "NextYearForecastOrdinaryProfit"
        case nextYearForecastProfit = "NextYearForecastProfit"
        case nextYearForecastEarningsPerShare = "NextYearForecastEarningsPerShare"
        case materialChangesInSubsidiaries = "MaterialChangesInSubsidiaries"
        case significantChangesInTheScopeOfConsolidation = "SignificantChangesInTheScopeOfConsolidation"
        case changesBasedOnRevisionsOfAccountingStandard = "ChangesBasedOnRevisionsOfAccountingStandard"
        case changesOtherThanOnesBasedOnRevisionsOfAccountingStandard = "ChangesOtherThanOnesBasedOnRevisionsOfAccountingStandard"
        case changesInAccountingEstimates = "ChangesInAccountingEstimates"
        case retrospectiveRestatement = "RetrospectiveRestatement"
        case numberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock = "NumberOfIssuedAndOutstandingSharesAtTheEndOfFiscalYearIncludingTreasuryStock"
        case numberOfTreasuryStockAtTheEndOfFiscalYear = "NumberOfTreasuryStockAtTheEndOfFiscalYear"
        case averageNumberOfShares = "AverageNumberOfShares"
        case nonConsolidatedNetSales = "NonConsolidatedNetSales"
        case nonConsolidatedOperatingProfit = "NonConsolidatedOperatingProfit"
        case nonConsolidatedOrdinaryProfit = "NonConsolidatedOrdinaryProfit"
        case nonConsolidatedProfit = "NonConsolidatedProfit"
        case nonConsolidatedEarningsPerShare = "NonConsolidatedEarningsPerShare"
        case nonConsolidatedTotalAssets = "NonConsolidatedTotalAssets"
        case nonConsolidatedEquity = "NonConsolidatedEquity"
        case nonConsolidatedEquityToAssetRatio = "NonConsolidatedEquityToAssetRatio"
        case nonConsolidatedBookValuePerShare = "NonConsolidatedBookValuePerShare"
        case forecastNonConsolidatedNetSales2ndQuarter = "ForecastNonConsolidatedNetSales2ndQuarter"
        case forecastNonConsolidatedOperatingProfit2ndQuarter = "ForecastNonConsolidatedOperatingProfit2ndQuarter"
        case forecastNonConsolidatedOrdinaryProfit2ndQuarter = "ForecastNonConsolidatedOrdinaryProfit2ndQuarter"
        case forecastNonConsolidatedProfit2ndQuarter = "ForecastNonConsolidatedProfit2ndQuarter"
        case forecastNonConsolidatedEarningsPerShare2ndQuarter = "ForecastNonConsolidatedEarningsPerShare2ndQuarter"
        case nextYearForecastNonConsolidatedNetSales2ndQuarter = "NextYearForecastNonConsolidatedNetSales2ndQuarter"
        case nextYearForecastNonConsolidatedOperatingProfit2ndQuarter = "NextYearForecastNonConsolidatedOperatingProfit2ndQuarter"
        case nextYearForecastNonConsolidatedOrdinaryProfit2ndQuarter = "NextYearForecastNonConsolidatedOrdinaryProfit2ndQuarter"
        case nextYearForecastNonConsolidatedProfit2ndQuarter = "NextYearForecastNonConsolidatedProfit2ndQuarter"
        case nextYearForecastNonConsolidatedEarningsPerShare2ndQuarter = "NextYearForecastNonConsolidatedEarningsPerShare2ndQuarter"
        case forecastNonConsolidatedNetSales = "ForecastNonConsolidatedNetSales"
        case forecastNonConsolidatedOperatingProfit = "ForecastNonConsolidatedOperatingProfit"
        case forecastNonConsolidatedOrdinaryProfit = "ForecastNonConsolidatedOrdinaryProfit"
        case forecastNonConsolidatedProfit = "ForecastNonConsolidatedProfit"
        case forecastNonConsolidatedEarningsPerShare = "ForecastNonConsolidatedEarningsPerShare"
        case nextYearForecastNonConsolidatedNetSales = "NextYearForecastNonConsolidatedNetSales"
        case nextYearForecastNonConsolidatedOperatingProfit = "NextYearForecastNonConsolidatedOperatingProfit"
        case nextYearForecastNonConsolidatedOrdinaryProfit = "NextYearForecastNonConsolidatedOrdinaryProfit"
        case nextYearForecastNonConsolidatedProfit = "NextYearForecastNonConsolidatedProfit"
        case nextYearForecastNonConsolidatedEarningsPerShare = "NextYearForecastNonConsolidatedEarningsPerShare"
    }
}
