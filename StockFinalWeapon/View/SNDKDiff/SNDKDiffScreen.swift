import SwiftUI
import SwiftSoup
import Combine

struct KioxiaData {
    let currentPrice: Double       // 円
    let marketCapMillionJPY: Double // 百万円
    let sharesOutstanding: Double   // 株
    var marketCapJPY: Double { marketCapMillionJPY * 1_000_000 }
}

class SNDKDiffViewModel: ObservableObject {
    @Published var usdJpy: Double?
    @Published var sndkMarketCapThousandUSD: Double?
    @Published var kioxia: KioxiaData?
    @Published var sndkRSI: Double?   // SNDK（サンディスク）の日足RSI(14)
    @Published var kioxiaRSI: Double? // キオクシア(285A)の日足RSI(14) 
    @Published var isLoading = false
    @Published var errorMessage: String?

    // SNDK時価総額(円)
    var sndkMarketCapJPY: Double? {
        guard let cap = sndkMarketCapThousandUSD, let rate = usdJpy else { return nil }
        return cap * 1_000 * rate
    }

    // キオクシアがSNDKと同じ時価総額になった場合の株価
    var kioxiaTargetPrice: Double? {
        guard let sndkJPY = sndkMarketCapJPY, let k = kioxia else { return nil }
        return sndkJPY / k.sharesOutstanding
    }

    // キオクシアがSNDK時価総額の +10% になった場合の株価
    var kioxiaTargetPricePlus10: Double? {
        guard let p = kioxiaTargetPrice else { return nil }
        return p * 1.1
    }

    // キオクシアがSNDK時価総額の −10% になった場合の株価
    var kioxiaTargetPriceMinus10: Double? {
        guard let p = kioxiaTargetPrice else { return nil }
        return p * 0.9
    }

    func fetchAll() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        async let sndkResult = fetchSNDKMarketCap()
        async let rateResult = fetchUSDJPY()
        async let kioxiaResult = fetchKioxia()
        async let sndkRSIResult = fetchRSI(identifier: "SNDK")
        async let kioxiaRSIResult = fetchRSI(identifier: "285A.T")

        let (sndk, rate, kioxiaData, sndkRSIValue, kioxiaRSIValue) =
            await (sndkResult, rateResult, kioxiaResult, sndkRSIResult, kioxiaRSIResult)

        DispatchQueue.main.async {
            self.sndkMarketCapThousandUSD = sndk
            self.usdJpy = rate
            self.kioxia = kioxiaData
            self.sndkRSI = sndkRSIValue
            self.kioxiaRSI = kioxiaRSIValue
            self.isLoading = false
        }
    }

    /// 日足チャートを取得してRSIを計算する。
    /// 楽天証券マーケットスピードの「短期」に合わせ、期間9・単純合計（カトラー式）で算出する。
    /// SwiftYFinanceのidentifierをそのまま使う（米国株は"SNDK"、東証は"285A.T"）。
    private func fetchRSI(identifier: String, period: Int = 9) async -> Double? {
        let end = Date()
        // 休日も考慮して約120日ぶんの日足を取得
        guard let start = Calendar.current.date(byAdding: .day, value: -120, to: end) else { return nil }
        do {
            let closes = try await SwiftYFinanceHelper.fetchDailyCloses(identifier: identifier, start: start, end: end)
            return RSICalculator.rsi(closes: closes, period: period, method: .simple)
        } catch {
            print("\(identifier) のRSI取得失敗: \(error)")
            return nil
        }
    }

    private func fetchSNDKMarketCap() async -> Double? {
        guard let url = URL(string: "https://finance.yahoo.co.jp/quote/SNDK") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let doc = try SwiftSoup.parse(html)
            for item in try doc.select("dl[class*=DataListItem]") {
                let term = try item.select("[class*=DataListItem__name]").text()
                guard term.contains("時価総額") else { continue }
                let value = try item.select("[class*=DataListItem__value]").text()
                return Double(value.replacingOccurrences(of: ",", with: ""))
            }
        } catch { print("SNDK取得失敗: \(error)") }
        return nil
    }

    private func fetchUSDJPY() async -> Double? {
        guard let url = URL(string: "https://finance.yahoo.co.jp/quote/USDJPY=X") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let doc = try SwiftSoup.parse(html)
            let value = try doc.select("span[class*=StyledNumber__value]").first()?.text() ?? ""
            return Double(value.replacingOccurrences(of: ",", with: ""))
        } catch { print("USDJPY取得失敗: \(error)") }
        return nil
    }

    private func fetchKioxia() async -> KioxiaData? {
        guard let url = URL(string: "https://finance.yahoo.co.jp/quote/285A.T") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let doc = try SwiftSoup.parse(html)

            // 現在株価
            let priceText = try doc.select("span[class*=StyledNumber__value]").first()?.text() ?? "0"
            let currentPrice = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? 0

            var marketCap = 0.0
            var shares = 0.0

            for item in try doc.select("dl[class*=DataListItem]") {
                let term = try item.select("[class*=DataListItem__name]").text()
                let value = try item.select("[class*=DataListItem__value]").text()
                let parsed = Double(value.replacingOccurrences(of: ",", with: "")) ?? 0
                if term.contains("時価総額") { marketCap = parsed }
                else if term.contains("発行済株式数") { shares = parsed }
            }

            guard shares > 0 else { return nil }
            return KioxiaData(currentPrice: currentPrice, marketCapMillionJPY: marketCap, sharesOutstanding: shares)
        } catch { print("キオクシア取得失敗: \(error)") }
        return nil
    }
}

struct SNDKDiffScreen: View {
    @StateObject private var viewModel = SNDKDiffViewModel()

    // 過熱とみなすRSIのしきい値（赤・🔥と背景の色付けで共有）
    private let sndkOverheat = 80.0
    private let kioxiaOverheat = 85.0

    // 買われすぎ（黄色背景）とみなすRSIのしきい値
    private let sndkHot = 75.0
    private let kioxiaHot = 80.0

    /// 画面全体の過熱度に応じた背景色（opacity込みで返す）
    /// - 両方が過熱 → 濃い赤（やばさMAX）
    /// - 片方が過熱 → 赤
    /// - 買われすぎ（SNDK 75以上 / キオクシア 80以上）のみ → 黄
    /// - それ以外 → なし
    private var overheatTint: Color? {
        func isAtOrAbove(_ rsi: Double?, _ threshold: Double) -> Bool {
            guard let rsi else { return false }
            return rsi >= threshold
        }

        let sndkOver = isAtOrAbove(viewModel.sndkRSI, sndkOverheat)
        let kioxiaOver = isAtOrAbove(viewModel.kioxiaRSI, kioxiaOverheat)

        if sndkOver && kioxiaOver {
            return Color.red.opacity(0.45) // 両方過熱 → 濃い赤
        }
        if sndkOver || kioxiaOver {
            return Color.red.opacity(0.25) // 片方過熱
        }
        if isAtOrAbove(viewModel.sndkRSI, sndkHot) || isAtOrAbove(viewModel.kioxiaRSI, kioxiaHot) {
            return Color.yellow.opacity(0.25) // 買われすぎ
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // USD/JPY
                    if let rate = viewModel.usdJpy {
                        InfoCard(title: "USD/JPY", value: String(format: "%.2f 円", rate))
                    }

                    // SNDK
                    SectionHeader(title: "SNDK（サンディスク）", rsi: viewModel.sndkRSI, overheatThreshold: sndkOverheat)
                    if let cap = viewModel.sndkMarketCapJPY {
                        InfoCard(title: "時価総額", value: formatJPY(cap))
                    }

                    // キオクシア
                    SectionHeader(title: "キオクシア（285A）", rsi: viewModel.kioxiaRSI, overheatThreshold: kioxiaOverheat)
                    if let k = viewModel.kioxia {
                        InfoCard(title: "現在株価", value: formatYen(k.currentPrice))
                        InfoCard(title: "時価総額", value: formatJPY(k.marketCapJPY))
                    }

                    // 目標株価
                    if let target = viewModel.kioxiaTargetPrice {
                        SectionHeader(title: "試算")
                        TargetPriceCard(
                            caption: "キオクシアがSNDKと同じ時価総額になった場合",
                            currentPrice: viewModel.kioxia?.currentPrice,
                            targetPrice: target,
                            accent: .yellow
                        )
                        if let plus10 = viewModel.kioxiaTargetPricePlus10 {
                            CompactTargetPriceCard(
                                caption: "SNDK時価総額 +10%",
                                currentPrice: viewModel.kioxia?.currentPrice,
                                targetPrice: plus10,
                                accent: .red
                            )
                        }
                        if let minus10 = viewModel.kioxiaTargetPriceMinus10 {
                            CompactTargetPriceCard(
                                caption: "SNDK時価総額 −10%",
                                currentPrice: viewModel.kioxia?.currentPrice,
                                targetPrice: minus10,
                                accent: .blue
                            )
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error).foregroundColor(.red).font(.caption).padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
            }
            // 過熱度に応じて画面全体の背景を色付け（買われすぎ→黄 / 過熱→赤）
            // systemBackgroundの上にtintを重ねるので、ライト/ダークどちらでも色が乗る
            .background(
                ZStack {
                    Color(.systemBackground)
                    if let overheatTint {
                        overheatTint
                    }
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: overheatTint)
            )
            // ローディングは中身を入れ替えず上に重ねる（大きいタイトルの高さ計算が崩れないように）
            .overlay {
                if viewModel.isLoading {
                    ProgressView("取得中...")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("SNDK差分")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.fetchAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .onAppear {
            Task { await viewModel.fetchAll() }
        }
    }

    private func formatJPY(_ value: Double) -> String {
        let trillion = 1_000_000_000_000.0
        let billion  = 100_000_000.0
        if value >= trillion {
            return String(format: "%.2f兆円", value / trillion)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value / billion)) ?? "") + "億円"
    }

    private func formatYen(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "") + "円"
    }
}

private struct SectionHeader: View {
    let title: String
    var rsi: Double? = nil  // 指定があれば銘柄名の横にRSI（短期9日）を小さく表示
    var overheatThreshold: Double? = nil  // このRSI以上で過熱とみなし🔥を表示

    private func rsiColor(_ v: Double) -> Color {
        if v >= 70 { return .red }   // 買われすぎ
        if v <= 30 { return .blue }  // 売られすぎ
        return .secondary
    }

    private func isOverheated(_ v: Double) -> Bool {
        guard let threshold = overheatThreshold else { return false }
        return v >= threshold
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
            if let rsi {
                HStack(spacing: 2) {
                    Text(String(format: "RSI %.1f", rsi))
                        .font(.caption.bold())
                        .foregroundColor(rsiColor(rsi))
                    if isOverheated(rsi) {
                        Text("⚠️⚠️⚠️").font(.caption)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

private struct InfoCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Text(value).font(.title2.bold())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal)
    }
}

private struct TargetPriceCard: View {
    let caption: String
    let currentPrice: Double?
    let targetPrice: Double
    var accent: Color = .accentColor

    private var upside: Double? {
        guard let cur = currentPrice, cur > 0 else { return nil }
        return (targetPrice - cur) / cur * 100
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text(formattedTarget)
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
            if let up = upside {
                Text(String(format: "現在比 %+.1f%%", up))
                    .font(.subheadline.bold())
                    .foregroundColor(up >= 0 ? .red : .blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent.opacity(0.15))
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.4), lineWidth: 1))
        .padding(.horizontal)
    }

    private var formattedTarget: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: targetPrice)) ?? "") + "円"
    }
}

/// 補助的な目標株価カード（コンパクト表示）
private struct CompactTargetPriceCard: View {
    let caption: String
    let currentPrice: Double?
    let targetPrice: Double
    var accent: Color = .accentColor

    private var upside: Double? {
        guard let cur = currentPrice, cur > 0 else { return nil }
        return (targetPrice - cur) / cur * 100
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(formattedTarget)
                .font(.headline)
                .foregroundColor(.primary)
            if let up = upside {
                Text(String(format: "%+.1f%%", up))
                    .font(.caption.bold())
                    .foregroundColor(up >= 0 ? .red : .blue)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accent.opacity(0.12))
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.35), lineWidth: 1))
        .padding(.horizontal)
    }

    private var formattedTarget: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: targetPrice)) ?? "") + "円"
    }
}

#Preview {
    SNDKDiffScreen()
}
