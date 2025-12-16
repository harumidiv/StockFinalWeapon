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
