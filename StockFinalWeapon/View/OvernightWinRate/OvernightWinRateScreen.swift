//
//  OvernightWinRateScreen.swift
//  StockFinalWeapon
//
//  銘柄コードを入力し、「終値で買って翌日の始値で売る」（オーバーナイト保有）戦略の
//  勝率を集計して表示する画面。
//

import SwiftUI
import Combine
import Charts

/// 集計期間
enum WinRatePeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1ヶ月"
    case threeMonths = "3ヶ月"
    case sixMonths = "6ヶ月"
    case oneYear = "1年"
    case allPeriod = "全期間"

    var id: Self { self }

    /// 取得に使う日数（休日を含むので余裕を持たせる）
    var days: Int {
        switch self {
        case .oneMonth: return 31
        case .threeMonths: return 93
        case .sixMonths: return 186
        case .oneYear: return 366
        case .allPeriod: return 36500 // 取得できる限り遡る（約100年）
        }
    }
}

/// 資産推移チャートの1点（初期投資額をそろえて各戦略を比較する）
struct OvernightEquityPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let overnight: Double    // オーバーナイト戦略（引け買い→翌寄り売りを毎日繰り返した）評価額・コスト前（円）
    let overnightNet: Double // 上記から 税(20.315%)・信用金利(年2.8%) を控除した実質手取り（円）
    let buyAndHold: Double   // 100株をずっと保有した場合の評価額（円）
}

/// 集計結果
struct OvernightWinRateResult {
    let code: String
    let totalTrades: Int    // トレード回数
    let wins: Int           // 勝ち（翌日始値 > 当日終値）
    let losses: Int         // 負け（翌日始値 < 当日終値）
    let draws: Int          // 引き分け（同値）
    let winRate: Double          // 勝率（％）
    let averageReturn: Double    // 1トレードあたり平均損益率（％）
    let cumulativeReturn: Double // 期間中ずっと繰り返した場合の累積リターン（％）
    let buyAndHoldReturn: Double // 期間中ずっと保有した場合の上昇率（％）
    let equityCurve: [OvernightEquityPoint] // 資産推移（2戦略の比較用）
    let startDate: Date?
    let endDate: Date?
}

extension OvernightWinRateResult {
    /// 取得したローソク足から「終値で買い、翌日始値で売る」戦略の集計結果を作る。
    /// 有効データが2本未満の場合は nil を返す。
    static func make(code: String, candles: [MyStockChartData]) -> OvernightWinRateResult? {
        // 有効な始値・終値のみを日付昇順に整理
        let bars = candles
            .compactMap { c -> (date: Date, open: Float, close: Float)? in
                guard let d = c.date, let o = c.open, let cl = c.close, o > 0, cl > 0 else { return nil }
                return (d, o, cl)
            }
            .sorted { $0.date < $1.date }

        guard bars.count >= 2 else { return nil }

        var wins = 0, losses = 0, draws = 0
        var returnSum = 0.0

        // 初期投資額をそろえる（最初の終値で 100株 買った金額）
        let shares = 100.0
        let firstClose = bars.first!.close
        let initialCapital = Double(firstClose) * shares

        // コスト設定
        let taxRate = 0.20315          // 譲渡益課税 20.315%
        let annualInterestRate = 0.028 // 信用金利 年2.8%
        let calendar = Calendar.current

        // 単利：毎回 100株 固定で売買し、損益はキャッシュとして積み上げる（再投資しない）
        var overnightEquity = initialCapital  // コスト前
        var cumulativeInterest = 0.0          // 累積の信用金利

        // 1点目（取引前。全戦略とも初期投資額からスタート）
        var equityCurve: [OvernightEquityPoint] = [
            OvernightEquityPoint(date: bars[0].date, overnight: initialCapital, overnightNet: initialCapital, buyAndHold: initialCapital)
        ]

        // 当日終値で買い、翌日始値で売る
        for i in 0..<(bars.count - 1) {
            let buy = bars[i].close
            let sell = bars[i + 1].open
            let ret = Double(sell - buy) / Double(buy)
            returnSum += ret

            if sell > buy {
                wins += 1
            } else if sell < buy {
                losses += 1
            } else {
                draws += 1
            }

            // 信用金利: 建玉（買い金額 = 100株ぶん）に対し、持ち越した日数ぶん課金
            let notional = Double(buy) * shares
            let daysHeld = max(1, calendar.dateComponents([.day], from: bars[i].date, to: bars[i + 1].date).day ?? 1)
            cumulativeInterest += notional * annualInterestRate * Double(daysHeld) / 365.0

            // 100株固定の損益をキャッシュに加算（単利）
            overnightEquity += Double(sell - buy) * shares

            // 税・金利控除後（実質手取り）。金利を引いた後、含み益にのみ課税し、損失は満額負担
            let afterInterest = overnightEquity - cumulativeInterest
            let netProfit = afterInterest - initialCapital
            let overnightNet = netProfit > 0 ? initialCapital + netProfit * (1 - taxRate) : afterInterest

            let buyAndHoldEquity = Double(bars[i + 1].close) * shares
            equityCurve.append(
                OvernightEquityPoint(date: bars[i + 1].date, overnight: overnightEquity, overnightNet: overnightNet, buyAndHold: buyAndHoldEquity)
            )
        }

        let total = bars.count - 1

        // 期間中ずっと保有した場合の上昇率（最初の終値で買い、最後の終値で売る）
        let lastClose = bars.last!.close
        let buyAndHoldReturn = Double(lastClose - firstClose) / Double(firstClose) * 100

        return OvernightWinRateResult(
            code: code,
            totalTrades: total,
            wins: wins,
            losses: losses,
            draws: draws,
            winRate: Double(wins) / Double(total) * 100,
            averageReturn: returnSum / Double(total) * 100,
            cumulativeReturn: (overnightEquity - initialCapital) / initialCapital * 100,
            buyAndHoldReturn: buyAndHoldReturn,
            equityCurve: equityCurve,
            startDate: bars.first?.date,
            endDate: bars.last?.date
        )
    }
}

@MainActor
final class OvernightWinRateViewModel: ObservableObject {
    @Published var result: OvernightWinRateResult?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 今日から period.days 分遡って集計する
    func calculate(code: String, period: WinRatePeriod) async {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -period.days, to: end) else { return }
        await calculate(code: code, start: start, end: end)
    }

    /// 開始日〜終了日を明示的に指定して集計する
    func calculate(code: String, start: Date, end: Date) async {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard start < end else {
            errorMessage = "開始日は終了日より前の日付を指定してください。"
            result = nil
            return
        }

        isLoading = true
        errorMessage = nil
        result = nil

        let apiResult = await YahooYFinanceAPIService().fetchStockChartData(code: trimmed, startDate: start, endDate: end)

        switch apiResult {
        case .success(let candles):
            guard let made = OvernightWinRateResult.make(code: trimmed, candles: candles) else {
                errorMessage = "データが不足しています。銘柄コードと期間をご確認ください。"
                isLoading = false
                return
            }
            result = made

        case .failure(let error):
            errorMessage = "取得に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

/// 期間の指定方法
enum WinRateRangeMode: String, CaseIterable, Identifiable {
    case preset = "期間プリセット"
    case custom = "日付指定"
    var id: Self { self }
}

struct OvernightWinRateScreen: View {
    @StateObject private var viewModel = OvernightWinRateViewModel()
    @State private var code: String = ""
    @State private var period: WinRatePeriod = .oneYear
    @State private var rangeMode: WinRateRangeMode = .preset
    @State private var startDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @FocusState private var isFocused: Bool

    /// 現在のモードに応じて計算を実行
    private func runCalculation() async {
        switch rangeMode {
        case .preset:
            await viewModel.calculate(code: code, period: period)
        case .custom:
            await viewModel.calculate(code: code, start: startDate, end: endDate)
        }
    }

    /// 現在のモードに応じた集計期間（開始日・終了日）。ランキング一覧へ引き継ぐ。
    private var resolvedRange: (start: Date, end: Date) {
        switch rangeMode {
        case .preset:
            let end = Date()
            let start = Calendar.current.date(byAdding: .day, value: -period.days, to: end) ?? end
            return (start, end)
        case .custom:
            return (startDate, endDate)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("当日の終値で買い、翌日の始値で売った場合（オーバーナイト保有）の勝率を集計します。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    // 入力フォーム
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("銘柄コード (例: 7203)", text: $code)
                            .focused($isFocused)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)

                        Picker("指定方法", selection: $rangeMode) {
                            ForEach(WinRateRangeMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch rangeMode {
                        case .preset:
                            Picker("期間", selection: $period) {
                                ForEach(WinRatePeriod.allCases) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                        case .custom:
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker("開始日", selection: $startDate, in: ...endDate, displayedComponents: .date)
                                DatePicker("終了日", selection: $endDate, in: startDate..., displayedComponents: .date)
                            }
                            .font(.system(size: 14))
                        }

                        Button(action: {
                            Task {
                                isFocused = false
                                await runCalculation()
                            }
                        }) {
                            Label("勝率を計算", systemImage: "chart.line.uptrend.xyaxis")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 20)
                    } else if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    } else if let result = viewModel.result {
                        OvernightWinRateResultCard(result: result)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("引in→寄out 勝率")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        let range = resolvedRange
                        OvernightWinRateRankingScreen(start: range.start, end: range.end)
                    } label: {
                        Image(systemName: "list.number")
                    }
                }
            }
        }
    }
}

/// 集計結果カード（入力画面・ランキング詳細画面で共用）
struct OvernightWinRateResultCard: View {
    let result: OvernightWinRateResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(result.code)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Spacer()
                if let s = result.startDate, let e = result.endDate {
                    Text("\(Self.dateText(s)) 〜 \(Self.dateText(e))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // 勝率（メイン表示）
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", result.winRate))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(result.winRate >= 50 ? .red : .blue)
                Text("%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(result.winRate >= 50 ? .red : .blue)
                Spacer()
            }

            Divider()

            statRow(label: "トレード回数", value: "\(result.totalTrades) 回")
            statRow(label: "勝ち / 負け / 引分", value: "\(result.wins) / \(result.losses) / \(result.draws)")
            statRow(
                label: "1回あたり平均損益率",
                value: String(format: "%+.3f%%", result.averageReturn),
                color: result.averageReturn >= 0 ? .red : .blue
            )
            statRow(
                label: "累積リターン（単利・100株固定）",
                value: String(format: "%+.2f%%", result.cumulativeReturn),
                color: result.cumulativeReturn >= 0 ? .red : .blue
            )
            statRow(
                label: "ずっと保有した場合の上昇率",
                value: String(format: "%+.2f%%", result.buyAndHoldReturn),
                color: result.buyAndHoldReturn >= 0 ? .red : .blue
            )

            if result.equityCurve.count >= 2 {
                Divider()
                equityChart
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private static let overnightLabel = "オーバーナイト戦略（単利・コスト前）"
    private static let overnightNetLabel = "税・金利控除後（手取り）"
    private static let buyAndHoldLabel = "100株ずっと保有"

    /// 初期投資額をそろえた各戦略の資産推移チャート
    @ViewBuilder
    private var equityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("資産推移（初期投資 = 最初の終値で100株購入）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Chart(result.equityCurve) { point in
                LineMark(
                    x: .value("日付", point.date),
                    y: .value("評価額", point.overnight)
                )
                .foregroundStyle(by: .value("系列", Self.overnightLabel))

                LineMark(
                    x: .value("日付", point.date),
                    y: .value("評価額", point.overnightNet)
                )
                .foregroundStyle(by: .value("系列", Self.overnightNetLabel))

                LineMark(
                    x: .value("日付", point.date),
                    y: .value("評価額", point.buyAndHold)
                )
                .foregroundStyle(by: .value("系列", Self.buyAndHoldLabel))
            }
            .chartForegroundStyleScale([
                Self.overnightLabel: Color.orange,
                Self.overnightNetLabel: Color.red,
                Self.buyAndHoldLabel: Color.blue
            ])
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let yen = value.as(Double.self) {
                            Text(Self.yenAxisText(yen))
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, spacing: 8)
            .frame(height: 220)
        }
    }

    /// Y軸ラベル用に円を「万」単位で短く表示する
    static func yenAxisText(_ yen: Double) -> String {
        if abs(yen) >= 10_000 {
            return String(format: "%.0f万", yen / 10_000)
        }
        return String(format: "%.0f", yen)
    }

    @ViewBuilder
    private func statRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}

#Preview {
    OvernightWinRateScreen()
}
