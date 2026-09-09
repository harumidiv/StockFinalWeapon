//
//  RSIChartScreen.swift
//  StockFinalWeapon
//
//  RSIチャート、売買バックテスト、指定RSIに必要な翌日終値を表示する。
//

import Charts
import Combine
import SwiftUI
import SwiftYFinance
import UIKit

private struct RSIDailyPrice: Identifiable {
    let date: Date
    let close: Double
    let adjustedClose: Double

    var id: Date { date }
}

private struct RSIChartPoint: Identifiable {
    let date: Date
    let close: Double
    let value: Double

    var id: Date { date }
}

private enum RSILine: String, CaseIterable, Identifiable {
    case short
    case long

    var id: Self { self }

    var period: Int {
        switch self {
        case .short: return 9
        case .long: return 14
        }
    }

    var title: String {
        switch self {
        case .short: return "短期（9日）"
        case .long: return "長期（14日）"
        }
    }
}

private enum RSIBacktestRange: Int, CaseIterable, Identifiable {
    case oneYear = 1
    case threeYears = 3
    case fiveYears = 5

    var id: Self { self }
    var title: String { "\(rawValue)年" }
}

private enum RSISection: String, CaseIterable, Identifiable {
    case chart
    case backtest
    case targetPrice

    var id: Self { self }

    var title: String {
        switch self {
        case .chart: return "チャート"
        case .backtest: return "バックテスト"
        case .targetPrice: return "翌日終値"
        }
    }
}

private enum RSIInputField: Hashable {
    case stockCode
    case buyRSI
    case sellRSI
    case targetRSI
}

private struct RSIKeyboardToolbar: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton(
                systemName: "chevron.up",
                accessibilityLabel: "前の入力欄へ戻る",
                isEnabled: canGoPrevious,
                action: onPrevious
            )
            toolbarButton(
                systemName: "chevron.down",
                accessibilityLabel: "次の入力欄へ進む",
                isEnabled: canGoNext,
                action: onNext
            )

            Spacer()

            toolbarButton(
                systemName: "checkmark",
                accessibilityLabel: "キーボードを閉じる",
                isEnabled: true,
                action: onDone
            )
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func toolbarButton(
        systemName: String,
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.35))
                .frame(width: 56, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

@MainActor
private final class RSIChartViewModel: ObservableObject {
    @Published private(set) var prices: [RSIDailyPrice] = []
    @Published private(set) var loadedIdentifier = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var latestClose: Double? { prices.last?.close }
    var latestDate: Date? { prices.last?.date }
    var isTokyoStock: Bool { loadedIdentifier.hasSuffix(".T") }

    func load(code: String) async {
        guard let identifier = Self.normalizedIdentifier(from: code) else {
            errorMessage = "銘柄コードを入力してください。"
            return
        }

        isLoading = true
        errorMessage = nil
        prices = []
        loadedIdentifier = ""
        defer { isLoading = false }

        let end = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        // 最大5年のバックテスト開始時点より前にも、RSI算出用の余裕を持たせる。
        guard let start = Calendar.current.date(byAdding: .month, value: -62, to: end) else {
            errorMessage = "取得期間を計算できませんでした。"
            return
        }

        do {
            let data = try await SwiftYFinanceHelper.fetchChartData(
                identifier: identifier,
                start: start,
                end: end
            )
            let fetchedPrices = data
                .compactMap { item -> RSIDailyPrice? in
                    guard let date = item.date,
                          let close = item.close.map(Double.init),
                          close.isFinite,
                          close > 0 else {
                        return nil
                    }
                    let adjustedClose = item.adjclose.map(Double.init) ?? close
                    return RSIDailyPrice(
                        date: date,
                        close: close,
                        adjustedClose: adjustedClose.isFinite && adjustedClose > 0 ? adjustedClose : close
                    )
                }
                .sorted { $0.date < $1.date }

            guard fetchedPrices.count >= 15 else {
                errorMessage = "株価データが不足しています。銘柄コードを確認してください。"
                return
            }

            prices = fetchedPrices
            loadedIdentifier = identifier
        } catch {
            errorMessage = "株価データを取得できませんでした。銘柄コードや通信状態を確認してください。"
        }
    }

    func chartPoints(period: Int) -> [RSIChartPoint] {
        let values = RSICalculator.rsiSeries(
            closes: prices.map(\.close),
            period: period,
            method: .simple
        )
        let allPoints = zip(prices, values).compactMap { price, value -> RSIChartPoint? in
            guard let value else { return nil }
            return RSIChartPoint(date: price.date, close: price.close, value: value)
        }

        // 計算には取得した全期間を使い、チャートは見やすく直近1年に絞る。
        guard let latestDate,
              let chartStart = Calendar.current.date(byAdding: .year, value: -1, to: latestDate) else {
            return allPoints
        }
        return allPoints.filter { $0.date >= chartStart }
    }

    func nextClose(
        targetRSI: Double,
        period: Int
    ) -> Double? {
        RSICalculator.nextClose(
            toReach: targetRSI,
            closes: prices.map(\.close),
            period: period,
            method: .simple
        )
    }

    func backtest(
        line: RSILine,
        range: RSIBacktestRange,
        buyThreshold: Double,
        sellThreshold: Double
    ) -> RSIBacktester.Result? {
        guard let latestDate,
              let startDate = Calendar.current.date(
                byAdding: .year,
                value: -range.rawValue,
                to: latestDate
              ) else {
            return nil
        }

        return RSIBacktester.run(
            dates: prices.map(\.date),
            // 長期検証で株式分割や配当により損益・RSIが歪まないよう調整後終値を使う。
            closes: prices.map(\.adjustedClose),
            period: line.period,
            method: .simple,
            buyThreshold: buyThreshold,
            sellThreshold: sellThreshold,
            startingAt: startDate
        )
    }

    private static func normalizedIdentifier(from input: String) -> String? {
        let trimmed = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains(".") { return trimmed }
        if trimmed.first?.isNumber == true { return "\(trimmed).T" }
        return trimmed
    }
}

struct RSIChartScreen: View {
    @StateObject private var viewModel = RSIChartViewModel()
    @State private var stockCode = "1570"
    @State private var selectedSection: RSISection = .chart
    @State private var targetLine: RSILine = .short
    @State private var targetRSIText = "30"
    @State private var targetPrice: Double?
    @State private var targetErrorMessage: String?
    @State private var backtestLine: RSILine = .short
    @State private var backtestRange: RSIBacktestRange = .threeYears
    @State private var buyRSIText = "30"
    @State private var sellRSIText = "70"
    @State private var backtestResult: RSIBacktester.Result?
    @State private var backtestErrorMessage: String?
    @State private var keyboardIsPresented = false
    @State private var selectedChartDate: Date?
    @FocusState private var focusedField: RSIInputField?

    private var shortChartPoints: [RSIChartPoint] {
        viewModel.chartPoints(period: RSILine.short.period)
    }

    private var longChartPoints: [RSIChartPoint] {
        viewModel.chartPoints(period: RSILine.long.period)
    }

    private var latestShortRSI: Double? { shortChartPoints.last?.value }
    private var latestLongRSI: Double? { longChartPoints.last?.value }

    private var selectedShortPoint: RSIChartPoint? {
        nearestPoint(to: selectedChartDate, in: shortChartPoints)
    }

    private var selectedLongPoint: RSIChartPoint? {
        nearestPoint(to: selectedChartDate, in: longChartPoints)
    }

    private var displayedDate: Date? {
        selectedShortPoint?.date ?? viewModel.latestDate
    }

    private var displayedShortRSI: Double? {
        selectedShortPoint?.value ?? latestShortRSI
    }

    private var displayedLongRSI: Double? {
        selectedLongPoint?.value ?? latestLongRSI
    }

    private var displayedClose: Double? {
        selectedShortPoint?.close ?? viewModel.latestClose
    }

    private var visibleInputFields: [RSIInputField] {
        switch selectedSection {
        case .chart:
            return [.stockCode]
        case .backtest:
            return [.stockCode, .buyRSI, .sellRSI]
        case .targetPrice:
            return [.stockCode, .targetRSI]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        searchCard
                            .id(RSIInputField.stockCode)

                        if viewModel.isLoading {
                            ProgressView("株価データを取得中…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else if let errorMessage = viewModel.errorMessage {
                            ContentUnavailableView(
                                "RSIを表示できません",
                                systemImage: "exclamationmark.triangle",
                                description: Text(errorMessage)
                            )
                            .padding(.vertical, 24)
                        } else if !shortChartPoints.isEmpty, !longChartPoints.isEmpty {
                            sectionPicker

                            switch selectedSection {
                            case .chart:
                                rsiChartCard
                            case .backtest:
                                backtestCard
                            case .targetPrice:
                                targetPriceCard
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .bottom) {
                    keyboardToolbar(using: proxy, fields: visibleInputFields)
                }
            }
            .background(Color(.systemGroupedBackground))
            .task {
                await loadStock()
            }
            .onChange(of: targetLine) { _, _ in calculateTargetPrice() }
            .onChange(of: backtestLine) { _, _ in calculateBacktest() }
            .onChange(of: backtestRange) { _, _ in calculateBacktest() }
            .onChange(of: selectedSection) { _, section in
                focusedField = nil
                if section == .backtest {
                    calculateBacktest()
                } else if section == .targetPrice {
                    calculateTargetPrice()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    keyboardIsPresented = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    keyboardIsPresented = false
                }
            }
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TextField("例: 7203 / AAPL", text: $stockCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .stockCode)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await loadStock() }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await loadStock() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("銘柄を検索")
            }

            Text("数字から始まる銘柄は東証（.T）として取得します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var rsiChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let displayedDate {
                Text("\(selectedChartDate == nil ? "最新" : "選択日") ・ \(displayedDate, format: .dateTime.year().month().day())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let displayedClose {
                HStack(alignment: .firstTextBaseline) {
                    Label(selectedChartDate == nil ? "最新終値" : "選択日の終値", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(priceText(displayedClose))
                        .font(.title2.bold())
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
                .padding(12)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 10) {
                latestRSICard(title: "短期（9日）", value: displayedShortRSI, color: .orange)
                latestRSICard(title: "長期（14日）", value: displayedLongRSI, color: .indigo)
            }

            Chart {
                RuleMark(y: .value("買われすぎ", 70))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))

                RuleMark(y: .value("売られすぎ", 30))
                    .foregroundStyle(.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))

                if let selectedShortPoint {
                    RuleMark(x: .value("選択日", selectedShortPoint.date))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("選択日", selectedShortPoint.date),
                        y: .value("短期RSI", selectedShortPoint.value)
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(55)
                }

                if let selectedLongPoint {
                    PointMark(
                        x: .value("選択日", selectedLongPoint.date),
                        y: .value("長期RSI", selectedLongPoint.value)
                    )
                    .foregroundStyle(.indigo)
                    .symbolSize(55)
                }

                ForEach(shortChartPoints) { point in
                    LineMark(
                        x: .value("日付", point.date),
                        y: .value("短期RSI", point.value)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                ForEach(longChartPoints) { point in
                    LineMark(
                        x: .value("日付", point.date),
                        y: .value("長期RSI", point.value)
                    )
                    .foregroundStyle(.indigo)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 30, 50, 70, 100])
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 2)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month())
                }
            }
            .chartXSelection(value: $selectedChartDate)
            .frame(height: 260)

            Label("チャートを左右になぞると、日付ごとのRSIを確認できます。", systemImage: "hand.draw")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("70以上: 買われすぎ", systemImage: "circle.fill")
                    .foregroundStyle(.red)
                Label("30以下: 売られすぎ", systemImage: "circle.fill")
                    .foregroundStyle(.blue)
            }
            .font(.caption2)
        }
        .cardStyle()
    }

    private var sectionPicker: some View {
        Picker("表示内容", selection: $selectedSection) {
            ForEach(RSISection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("RSIの表示内容")
        .padding(4)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var targetPriceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("指定RSIに必要な翌日終値")
                .font(.headline)

            Text("直近終値の次に1日分の終値を追加したときの株価を逆算します。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("計算対象", selection: $targetLine) {
                ForEach(RSILine.allCases) { line in
                    Text(line.title).tag(line)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                TextField("例: 30", text: $targetRSIText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .targetRSI)
                    .id(RSIInputField.targetRSI)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("目標RSI")

                Button("計算") {
                    calculateTargetPrice()
                }
                .buttonStyle(.borderedProminent)
            }

            if let targetPrice, let latestClose = viewModel.latestClose {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(targetLine.title)の翌日終値")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(priceText(targetPrice))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    let changeRate = (targetPrice / latestClose - 1) * 100
                    Text("直近終値 \(priceText(latestClose)) から \(changeRate >= 0 ? "+" : "")\(changeRate, format: .number.precision(.fractionLength(2)))%")
                        .font(.subheadline)
                        .foregroundStyle(changeRate >= 0 ? .red : .blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            } else if let targetErrorMessage {
                Label(targetErrorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .cardStyle()
    }

    private var backtestCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RSI売買バックテスト")
                    .font(.headline)
                Text("買いRSI以下で買い、売りRSI以上で売却する取引を繰り返します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("RSI期間", selection: $backtestLine) {
                ForEach(RSILine.allCases) { line in
                    Text(line.title).tag(line)
                }
            }
            .pickerStyle(.segmented)

            Picker("検証期間", selection: $backtestRange) {
                ForEach(RSIBacktestRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                thresholdField(
                    title: "買い（以下）",
                    text: $buyRSIText,
                    field: .buyRSI,
                    color: .blue
                )
                thresholdField(
                    title: "売り（以上）",
                    text: $sellRSIText,
                    field: .sellRSI,
                    color: .red
                )
            }

            Button {
                calculateBacktest()
                focusedField = nil
            } label: {
                Label("バックテストを実行", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let result = backtestResult {
                backtestResultView(result)
            } else if let backtestErrorMessage {
                Label(backtestErrorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("日足の調整後終値（株式分割・配当調整済み）で売買し、毎回全資金を投入した複利計算です。手数料・税金・スリッページは含みません。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func thresholdField(
        title: String,
        text: Binding<String>,
        field: RSIInputField,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(color)
            TextField("0〜100", text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .id(field)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("\(title)のRSI")
        }
        .frame(maxWidth: .infinity)
    }

    private func backtestResultView(_ result: RSIBacktester.Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("\(result.startDate, format: .dateTime.year().month().day()) 〜 \(result.endDate, format: .dateTime.year().month().day())")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                backtestMetric(
                    title: "累積損益",
                    value: signedPercentageText(result.totalReturnPercentage),
                    color: profitColor(result.totalReturnPercentage)
                )
                backtestMetric(
                    title: "勝率",
                    value: result.winRatePercentage.map { percentageText($0) } ?? "--",
                    color: .accentColor
                )
                backtestMetric(
                    title: "決済回数",
                    value: "\(result.trades.count)回",
                    color: .primary
                )
            }

            VStack(spacing: 7) {
                backtestComparisonRow(
                    title: "買い持ち損益",
                    value: signedPercentageText(result.buyAndHoldReturnPercentage),
                    color: profitColor(result.buyAndHoldReturnPercentage)
                )
                if result.openPosition != nil {
                    backtestComparisonRow(
                        title: "決済済み累積損益",
                        value: signedPercentageText(result.realizedReturnPercentage),
                        color: profitColor(result.realizedReturnPercentage)
                    )
                }
                backtestComparisonRow(
                    title: "1取引の平均",
                    value: result.averageTradeReturnPercentage.map { signedPercentageText($0) } ?? "--",
                    color: result.averageTradeReturnPercentage.map(profitColor) ?? .secondary
                )
                backtestComparisonRow(
                    title: "勝ち / 負け",
                    value: "\(result.winCount) / \(result.trades.count - result.winCount)",
                    color: .primary
                )
            }

            if let position = result.openPosition {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("保有中（勝率には未算入）")
                            .font(.subheadline.weight(.semibold))
                        Text("\(position.buyDate, format: .dateTime.year().month().day()) に \(priceText(position.buyPrice)) で買い ・ 評価損益 \(signedPercentageText(position.returnPercentage))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            if !result.trades.isEmpty {
                DisclosureGroup("取引履歴（直近最大10件）") {
                    VStack(spacing: 0) {
                        ForEach(Array(result.trades.suffix(10).reversed())) { trade in
                            tradeRow(trade)
                            if trade.id != result.trades.suffix(10).first?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.subheadline)
            } else {
                Text("条件を満たす決済済み取引はありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func backtestMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func backtestComparisonRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .font(.subheadline)
    }

    private func tradeRow(_ trade: RSIBacktester.Trade) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trade.buyDate, format: .dateTime.year().month().day()) → \(trade.sellDate, format: .dateTime.year().month().day())")
                    .font(.caption)
                Text("\(priceText(trade.buyPrice)) → \(priceText(trade.sellPrice))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(signedPercentageText(trade.returnPercentage))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(profitColor(trade.returnPercentage))
        }
        .padding(.vertical, 7)
    }

    private func loadStock() async {
        targetPrice = nil
        targetErrorMessage = nil
        backtestResult = nil
        backtestErrorMessage = nil
        selectedChartDate = nil
        await viewModel.load(code: stockCode)
        if !viewModel.prices.isEmpty {
            calculateTargetPrice()
            calculateBacktest()
        }
    }

    private func calculateBacktest() {
        backtestResult = nil
        backtestErrorMessage = nil

        guard let buyRSI = parsedRSI(buyRSIText),
              let sellRSI = parsedRSI(sellRSIText) else {
            backtestErrorMessage = "買い・売りRSIは0〜100の数値で入力してください。"
            return
        }
        guard buyRSI < sellRSI else {
            backtestErrorMessage = "買いRSIは売りRSIより小さくしてください。"
            return
        }
        guard let result = viewModel.backtest(
            line: backtestLine,
            range: backtestRange,
            buyThreshold: buyRSI,
            sellThreshold: sellRSI
        ) else {
            backtestErrorMessage = "バックテストに必要な株価データが不足しています。"
            return
        }
        backtestResult = result
    }

    private func calculateTargetPrice() {
        targetPrice = nil
        targetErrorMessage = nil

        let normalizedText = targetRSIText
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let targetRSI = Double(normalizedText), targetRSI > 0, targetRSI < 100 else {
            targetErrorMessage = "RSIは0より大きく100より小さい数値で入力してください。"
            return
        }

        guard let calculatedPrice = viewModel.nextClose(
            targetRSI: targetRSI,
            period: targetLine.period
        ) else {
            targetErrorMessage = "翌日終値を0以上として、指定RSIには到達できません。"
            return
        }
        targetPrice = calculatedPrice
    }

    @ViewBuilder
    private func keyboardToolbar(
        using proxy: ScrollViewProxy,
        fields: [RSIInputField]
    ) -> some View {
        if keyboardIsPresented {
            let previous = adjacentField(offset: -1, in: fields)
            let next = adjacentField(offset: 1, in: fields)
            RSIKeyboardToolbar(
                canGoPrevious: previous != nil,
                canGoNext: next != nil,
                onPrevious: { moveFocus(to: previous, using: proxy) },
                onNext: { moveFocus(to: next, using: proxy) },
                onDone: { focusedField = nil }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func adjacentField(
        offset: Int,
        in fields: [RSIInputField]
    ) -> RSIInputField? {
        guard let focusedField,
              let currentIndex = fields.firstIndex(of: focusedField) else {
            return nil
        }
        let targetIndex = currentIndex + offset
        guard fields.indices.contains(targetIndex) else { return nil }
        return fields[targetIndex]
    }

    private func moveFocus(to field: RSIInputField?, using proxy: ScrollViewProxy) {
        guard let field else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(field, anchor: .center)
        } completion: {
            focusedField = field
        }
    }

    private func nearestPoint(to date: Date?, in points: [RSIChartPoint]) -> RSIChartPoint? {
        guard let date else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private func parsedRSI(_ text: String) -> Double? {
        let normalizedText = text
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalizedText), (0...100).contains(value) else { return nil }
        return value
    }

    private func percentageText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1))))%"
    }

    private func signedPercentageText(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "")\(value.formatted(.number.precision(.fractionLength(2))))%"
    }

    private func profitColor(_ value: Double) -> Color {
        if value > 0 { return .red }
        if value < 0 { return .blue }
        return .secondary
    }

    private func priceText(_ price: Double) -> String {
        let number = price.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(2))
        )
        return viewModel.isTokyoStock ? "\(number)円" : number
    }

    private func latestRSICard(title: String, value: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let value {
                Text(value, format: .number.precision(.fractionLength(1)))
                    .font(.title2.bold())
                    .foregroundStyle(color)
            } else {
                Text("--")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    RSIChartScreen()
}
