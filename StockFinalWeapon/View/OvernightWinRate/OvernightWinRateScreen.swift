//
//  OvernightWinRateScreen.swift
//  StockFinalWeapon
//
//  銘柄コードを入力し、「終値で買って翌日の始値で売る」（オーバーナイト保有）戦略の
//  勝率を集計して表示する画面。
//

import SwiftUI
import Combine

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
    let startDate: Date?
    let endDate: Date?
}

@MainActor
final class OvernightWinRateViewModel: ObservableObject {
    @Published var result: OvernightWinRateResult?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func calculate(code: String, period: WinRatePeriod) async {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        result = nil

        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -period.days, to: end) else {
            isLoading = false
            return
        }

        let apiResult = await YahooYFinanceAPIService().fetchStockChartData(code: trimmed, startDate: start, endDate: end)

        switch apiResult {
        case .success(let candles):
            // 有効な始値・終値のみを日付昇順に整理
            let bars = candles
                .compactMap { c -> (date: Date, open: Float, close: Float)? in
                    guard let d = c.date, let o = c.open, let cl = c.close, o > 0, cl > 0 else { return nil }
                    return (d, o, cl)
                }
                .sorted { $0.date < $1.date }

            guard bars.count >= 2 else {
                errorMessage = "データが不足しています。銘柄コードと期間をご確認ください。"
                isLoading = false
                return
            }

            var wins = 0, losses = 0, draws = 0
            var returnSum = 0.0
            var cumulative = 1.0

            // 当日終値で買い、翌日始値で売る
            for i in 0..<(bars.count - 1) {
                let buy = bars[i].close
                let sell = bars[i + 1].open
                let ret = Double(sell - buy) / Double(buy)
                returnSum += ret
                cumulative *= (1 + ret)

                if sell > buy {
                    wins += 1
                } else if sell < buy {
                    losses += 1
                } else {
                    draws += 1
                }
            }

            let total = bars.count - 1
            result = OvernightWinRateResult(
                code: trimmed,
                totalTrades: total,
                wins: wins,
                losses: losses,
                draws: draws,
                winRate: Double(wins) / Double(total) * 100,
                averageReturn: returnSum / Double(total) * 100,
                cumulativeReturn: (cumulative - 1) * 100,
                startDate: bars.first?.date,
                endDate: bars.last?.date
            )

        case .failure(let error):
            errorMessage = "取得に失敗しました: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

struct OvernightWinRateScreen: View {
    @StateObject private var viewModel = OvernightWinRateViewModel()
    @State private var code: String = ""
    @State private var period: WinRatePeriod = .oneYear
    @FocusState private var isFocused: Bool

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

                        Picker("期間", selection: $period) {
                            ForEach(WinRatePeriod.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button(action: {
                            Task {
                                isFocused = false
                                await viewModel.calculate(code: code, period: period)
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
                        resultCard(result)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("引in→寄out 勝率")
            // 期間を変えたら、すでに結果がある場合は再計算
            .onChange(of: period) { _, _ in
                guard viewModel.result != nil || viewModel.errorMessage != nil else { return }
                Task { await viewModel.calculate(code: code, period: period) }
            }
        }
    }

    @ViewBuilder
    private func resultCard(_ result: OvernightWinRateResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(result.code)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                Spacer()
                if let s = result.startDate, let e = result.endDate {
                    Text("\(dateText(s)) 〜 \(dateText(e))")
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
                label: "累積リターン（複利）",
                value: String(format: "%+.2f%%", result.cumulativeReturn),
                color: result.cumulativeReturn >= 0 ? .red : .blue
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
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

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}

#Preview {
    OvernightWinRateScreen()
}
