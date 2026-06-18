//
//  OvernightWinRateRankingScreen.swift
//  StockFinalWeapon
//
//  売買代金上位50銘柄について「終値で買って翌日の始値で売る」（オーバーナイト保有）
//  戦略の勝率を計算し、勝率が高い順に一覧表示する画面。
//  行をタップすると詳細（結果カード）を表示する。
//

import SwiftUI
import SwiftSoup
import Combine

/// 一覧の1行ぶん（売買代金ランキングの銘柄 + その勝率集計結果）
struct RankedWinRateRow: Identifiable {
    let id = UUID()
    let tradingRank: Int   // 売買代金ランキング順位
    let code: String
    let name: String
    let result: OvernightWinRateResult
}

/// Yahoo Finance の売買代金ランキングから上位銘柄（順位・コード・銘柄名）を取得する
struct TradingValueRankingFetcher {
    struct Entry {
        let rank: Int
        let code: String
        let name: String
    }

    func fetchTop(_ limit: Int) async -> [Entry] {
        let urlString = "https://finance.yahoo.co.jp/stocks/ranking/tradingValueHigh?market=all&term=daily"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            let doc = try SwiftSoup.parse(html)
            let entries = try extractEntries(from: doc)
            return Array(entries.prefix(limit))
        } catch {
            print("売買代金ランキングの取得に失敗: \(error)")
            return []
        }
    }

    /// scriptタグを走査し __PRELOADED_STATE__ JSON から順位・コード・銘柄名を抽出
    private func extractEntries(from doc: Document) throws -> [Entry] {
        for script in try doc.select("script") {
            let content = try script.html()
            guard content.contains("__PRELOADED_STATE__"),
                  let range = content.range(of: "window.__PRELOADED_STATE__ = ") else { continue }
            var jsonStr = String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonStr.hasSuffix(";") { jsonStr = String(jsonStr.dropLast()) }
            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let results = findRankingResults(in: json) else { continue }
            return results.compactMap { item in
                let rank: Int
                if let s = item["rank"] as? String, let r = Int(s) { rank = r }
                else if let r = item["rank"] as? Int { rank = r }
                else { return nil }
                guard let code = item["stockCode"] as? String else { return nil }
                let name = (item["name"] as? String) ?? (item["stockName"] as? String) ?? code
                return Entry(rank: rank, code: code, name: name)
            }
        }
        return []
    }

    /// JSONを再帰探索して mainRankingList.results を返す
    private func findRankingResults(in json: [String: Any]) -> [[String: Any]]? {
        if let list = json["mainRankingList"] as? [String: Any],
           let results = list["results"] as? [[String: Any]] {
            return results
        }
        for (_, value) in json {
            if let nested = value as? [String: Any],
               let found = findRankingResults(in: nested) { return found }
        }
        return nil
    }
}

@MainActor
final class OvernightWinRateRankingViewModel: ObservableObject {
    @Published var rows: [RankedWinRateRow] = []
    @Published var isLoading = false
    @Published var progress = ""
    @Published var errorMessage: String?

    func load(start: Date, end: Date) async {
        isLoading = true
        errorMessage = nil
        rows = []
        progress = ""

        let entries = await TradingValueRankingFetcher().fetchTop(50)
        guard !entries.isEmpty else {
            errorMessage = "売買代金ランキングの取得に失敗しました。時間をおいて再度お試しください。"
            isLoading = false
            return
        }

        var computed: [RankedWinRateRow] = []
        // API負荷を抑えるため10件ずつ並列で取得
        for chunkStart in stride(from: 0, to: entries.count, by: 10) {
            let chunk = Array(entries[chunkStart..<min(chunkStart + 10, entries.count)])
            let chunkRows = await withTaskGroup(of: RankedWinRateRow?.self) { group in
                for entry in chunk {
                    group.addTask {
                        let apiResult = await YahooYFinanceAPIService()
                            .fetchStockChartData(code: entry.code, startDate: start, endDate: end)
                        switch apiResult {
                        case .success(let candles):
                            guard let result = OvernightWinRateResult.make(code: entry.code, candles: candles) else {
                                return nil
                            }
                            return RankedWinRateRow(
                                tradingRank: entry.rank,
                                code: entry.code,
                                name: entry.name,
                                result: result
                            )
                        case .failure:
                            return nil
                        }
                    }
                }
                var batch: [RankedWinRateRow] = []
                for await row in group {
                    if let row { batch.append(row) }
                }
                return batch
            }
            computed.append(contentsOf: chunkRows)
            progress = "\(computed.count) / \(entries.count) 銘柄"
        }

        // 勝率が高い順に並べる
        rows = computed.sorted { $0.result.winRate > $1.result.winRate }
        isLoading = false
    }
}

/// 一覧の並び順
enum WinRateRankingSort: String, CaseIterable, Identifiable {
    case winRate = "勝率"
    case cumulative = "累積"
    var id: Self { self }

    var headerSuffix: String {
        switch self {
        case .winRate: return "勝率が高い順"
        case .cumulative: return "累積リターンが高い順"
        }
    }
}

struct OvernightWinRateRankingScreen: View {
    @StateObject private var viewModel = OvernightWinRateRankingViewModel()
    @State private var rangeMode: WinRateRangeMode = .custom
    @State private var period: WinRatePeriod = .oneYear
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var sortKey: WinRateRankingSort = .winRate

    init(start: Date, end: Date) {
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    /// 並び順に応じて並べ替えた行（再取得は不要、その場で並べ替えるだけ）
    private var sortedRows: [RankedWinRateRow] {
        switch sortKey {
        case .winRate:
            return viewModel.rows.sorted { $0.result.winRate > $1.result.winRate }
        case .cumulative:
            return viewModel.rows.sorted { $0.result.cumulativeReturn > $1.result.cumulativeReturn }
        }
    }

    /// 現在のモードに応じた集計期間（開始日・終了日）
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
        VStack(spacing: 0) {
            // 期間指定（変更すると一覧全体を再取得する）
            VStack(alignment: .leading, spacing: 12) {
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
            }
            .padding()
            .disabled(viewModel.isLoading)

            Divider()

            content
        }
        .navigationTitle("上位50銘柄の勝率")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.isLoading {
                    Button {
                        reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        // 期間・指定方法・日付を変えたら一覧を再取得
        .onChange(of: rangeMode) { _, _ in reload() }
        .onChange(of: period) { _, _ in reload() }
        .onChange(of: startDate) { _, _ in reload() }
        .onChange(of: endDate) { _, _ in reload() }
        .task {
            if viewModel.rows.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                reload()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                Text("売買代金上位50銘柄の勝率を計算中...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if !viewModel.progress.isEmpty {
                    Text(viewModel.progress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        } else if let message = viewModel.errorMessage {
            Spacer()
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .padding()
            Spacer()
        } else {
            let range = resolvedRange
            VStack(spacing: 0) {
                // 並び順の切り替え（勝率／累積）
                Picker("並び順", selection: $sortKey) {
                    ForEach(WinRateRankingSort.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    Section {
                        ForEach(Array(sortedRows.enumerated()), id: \.element.id) { index, row in
                            NavigationLink {
                                OvernightWinRateDetailScreen(row: row, start: range.start, end: range.end)
                            } label: {
                                rankingRow(order: index + 1, row: row)
                            }
                        }
                    } header: {
                        Text("\(OvernightWinRateResultCard.dateText(range.start)) 〜 \(OvernightWinRateResultCard.dateText(range.end))・\(sortKey.headerSuffix)")
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    /// 現在の期間設定で一覧を再取得する
    private func reload() {
        let range = resolvedRange
        Task { await viewModel.load(start: range.start, end: range.end) }
    }

    @ViewBuilder
    private func rankingRow(order: Int, row: RankedWinRateRow) -> some View {
        HStack(spacing: 12) {
            Text("\(order)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                Text("\(row.code)・売買代金\(row.tradingRank)位")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%%", row.result.winRate))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(row.result.winRate >= 50 ? .red : .blue)
                Text(String(format: "累積%+.1f%%", row.result.cumulativeReturn))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(String(format: "保有%+.1f%%", row.result.buyAndHoldReturn))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 一覧から遷移する詳細画面。銘柄を固定したまま期間を変えて再計算できる。
struct OvernightWinRateDetailScreen: View {
    let row: RankedWinRateRow

    @StateObject private var viewModel = OvernightWinRateViewModel()
    @State private var rangeMode: WinRateRangeMode = .custom
    @State private var period: WinRatePeriod = .oneYear
    @State private var startDate: Date
    @State private var endDate: Date

    init(row: RankedWinRateRow, start: Date, end: Date) {
        self.row = row
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.name)
                        .font(.system(size: 20, weight: .bold))
                    Text("\(row.code)・売買代金ランキング \(row.tradingRank)位")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // 期間指定（この銘柄だけ期間を変えて再計算できる）
                VStack(alignment: .leading, spacing: 12) {
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
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 12)
                } else if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                } else {
                    // まだ再計算していなければ一覧で計算済みの結果を表示する
                    OvernightWinRateResultCard(result: viewModel.result ?? row.result)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(row.code)
        .navigationBarTitleDisplayMode(.inline)
        // 期間・指定方法・日付を変えたら再計算
        .onChange(of: rangeMode) { _, _ in recalculate() }
        .onChange(of: period) { _, _ in recalculate() }
        .onChange(of: startDate) { _, _ in recalculate() }
        .onChange(of: endDate) { _, _ in recalculate() }
    }

    /// 現在のモードに応じてこの銘柄を再計算する
    private func recalculate() {
        Task {
            switch rangeMode {
            case .preset:
                await viewModel.calculate(code: row.code, period: period)
            case .custom:
                await viewModel.calculate(code: row.code, start: startDate, end: endDate)
            }
        }
    }
}
