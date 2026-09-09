//
//  RSIChartScreen.swift
//  StockFinalWeapon
//
//  入力した銘柄のRSIチャートと、指定RSIに必要な翌日終値を表示する。
//

import Charts
import Combine
import SwiftUI
import SwiftYFinance
import UIKit

private struct RSIDailyPrice: Identifiable {
    let date: Date
    let close: Double

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

private enum RSIInputField: Hashable {
    case stockCode
    case targetRSI

    var previous: RSIInputField? {
        switch self {
        case .stockCode: return nil
        case .targetRSI: return .stockCode
        }
    }

    var next: RSIInputField? {
        switch self {
        case .stockCode: return .targetRSI
        case .targetRSI: return nil
        }
    }
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
        guard let start = Calendar.current.date(byAdding: .month, value: -18, to: end) else {
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
                    return RSIDailyPrice(date: date, close: close)
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
    @State private var targetLine: RSILine = .short
    @State private var targetRSIText = "20"
    @State private var targetPrice: Double?
    @State private var targetErrorMessage: String?
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

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        searchCard
                            .id(RSIInputField.stockCode)
                        rsiPeriodCard

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
                            rsiChartCard
                            targetPriceCard
                                .id(RSIInputField.targetRSI)
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .bottom) {
                    if keyboardIsPresented {
                        RSIKeyboardToolbar(
                            canGoPrevious: focusedField?.previous != nil,
                            canGoNext: focusedField?.next != nil,
                            onPrevious: { moveFocus(to: focusedField?.previous, using: proxy) },
                            onNext: { moveFocus(to: focusedField?.next, using: proxy) },
                            onDone: { focusedField = nil }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            .navigationTitle("RSIチャート")
            .background(Color(.systemGroupedBackground))
            .task {
                await loadStock()
            }
            .onChange(of: targetLine) { _, _ in calculateTargetPrice() }
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("銘柄コード")
                .font(.headline)

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

    private var rsiPeriodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                Label {
                    Text("短期 9日")
                } icon: {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.orange)
                }

                Label {
                    Text("長期 14日")
                } icon: {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.indigo)
                }
            }

            Text("楽天証券iSPEEDの日足初期値と同じ期間で、値上がり幅・値下がり幅の単純合計から算出します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var rsiChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.loadedIdentifier)
                    .font(.headline)
                if let displayedDate {
                    Text("\(selectedChartDate == nil ? "最新" : "選択日") ・ \(displayedDate, format: .dateTime.year().month().day())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                TextField("例: 20", text: $targetRSIText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .targetRSI)
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

    private func loadStock() async {
        targetPrice = nil
        targetErrorMessage = nil
        selectedChartDate = nil
        await viewModel.load(code: stockCode)
        if !viewModel.prices.isEmpty {
            calculateTargetPrice()
        }
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
