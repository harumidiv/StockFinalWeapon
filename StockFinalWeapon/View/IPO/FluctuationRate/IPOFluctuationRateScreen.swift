//
//  IPOFluctuationRateScreen.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/07/16.
//

import SwiftUI
import SwiftSoup

struct IPOInfo {
    let year: String
    let stockCodes: [String]
}

enum ComparisonType: String, CaseIterable, Identifiable {
    case greaterThanOrEqual = "以上"
    case lessThanOrEqual = "以下"
    
    var id: Self { self }
}

struct IPOFluctuationRateScreen: View {
    @State private var ipoInfos: [IPOInfo] = []
    @State private var threshold: Float = 100.0
    @State private var selectedComparison: ComparisonType = .greaterThanOrEqual
    
    
    var body: some View {
        NavigationStack {
            Group {
                if ipoInfos.isEmpty {
                    ProgressView()
                } else {
                    VStack {
                        HStack {
                            Text("しきい値: \(Int(threshold))%")
                                .font(.headline)
                                .monospacedDigit()
                            Picker("比較条件", selection: $selectedComparison) {
                                ForEach(ComparisonType.allCases) { type in
                                    Text("\(type.rawValue)")
                                }
                            }
                            .frame(width: 100)
                        }
                        Slider(value: $threshold, in: -100...300, step: 1)
                            .padding(.horizontal)
                        
                        List(ipoInfos, id: \.year) { info in
                            NavigationLink(destination: IPODetailScreen(priceRizeParcentage: threshold, ipoInfo: info, comparison: selectedComparison)) {
                                Text("\(info.year)年")
                            }
                        }
                    }
                }
            }
            .navigationTitle("IPO騰落率")
        }
        .task {
            if ipoInfos.isEmpty {
                ipoInfos = await createIpoInfos()
            }
        }
    }
    
    func createIpoInfos() async -> [IPOInfo] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let baseURL = "https://www.ipokiso.com/company/"
        var infos: [IPOInfo] = []
        for year in (2011...currentYear).reversed() {
            let url = baseURL + year.description + ".html"
            if let html = await URL(string: url)?.fetchHtml() {
                do {
                    let codes: [String]
                    if year > 2017 {
                        codes = try extractAllStockCodes(from: html)
                    } else if year == 2017 || year == 2016 {
                        codes = try extractAllStockCodes2017AndBefore(from: html)
                    } else {
                        codes = try extractAllStockCodes2015AndBefore(from: html)
                    }
                    
                    infos.append(IPOInfo(year: "\(year)", stockCodes: codes))
                } catch {
                    print("❌ Parse error for year \(year): \(error)")
                }
            }
        }
        return infos
    }
    
    ///  銘柄コードのスクレイピング
    /// - Parameter html: html
    /// - Returns: 銘柄コードの配列
    func extractAllStockCodes(from html: String) throws -> [String] {
        let doc = try SwiftSoup.parse(html)
        let tds = try doc.select("div.tableHead td")
        
        // 正規表現パターン：括弧付きでちょうど英数字4文字
        let pattern = #"^\(([A-Za-z0-9]{4})\)$"#
        let regex = try NSRegularExpression(pattern: pattern)
        
        var results = [String]()
        
        for td in tds.array() {
            let fullText = try td.text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 日本語括弧「（）」と欧米括弧「()」の両方で分割
            let comps = fullText.components(separatedBy: CharacterSet(charactersIn: "（）()"))
            
            for comp in comps {
                let candidate = "(\(comp))"  // 再び括弧付きに再構築
                let ns = candidate as NSString
                let range = NSRange(location: 0, length: ns.length)
                
                regex.enumerateMatches(in: candidate, options: [], range: range) { match, _, _ in
                    guard let match = match, match.numberOfRanges >= 2 else { return }
                    let code = ns.substring(with: match.range(at: 1))
                    results.append(code)
                }
            }
        }
        
        // 重複を排除して返す
        return Array(Set(results))
    }
    
    func extractAllStockCodes2017AndBefore(from html: String) throws -> [String] {
        let pattern = #"[\(（]([0-9]{4})[\)）]"#  // ()で囲まれた4桁の数字
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
        
        var results: [String] = []
        
        regex?.enumerateMatches(in: html, options: [], range: nsrange) { match, _, _ in
            if let match = match, let range = Range(match.range(at: 1), in: html) {
                results.append(String(html[range]))
            }
        }
        
        return results
    }
    
    
    /// 2015年以前のデータの取得
    /// - Parameter html: html
    /// - Returns: IPOの銘柄リスト
    func extractAllStockCodes2015AndBefore(from html: String) throws -> [String] {
        let document = try SwiftSoup.parse(html)
        let rows = try document.select("table.sche tbody tr")
        
        var stockCodes: [String] = []
        
        for row in rows {
            let tds = try row.select("td")
            if tds.count >= 3 {
                // 3列目が銘柄コード（0始まりなので index 2）
                let code = try tds[2].text().trimmingCharacters(in: .whitespacesAndNewlines)
                // 数字4桁 or アルファベット混じりも対応（例: "148A"）
                if code.range(of: #"^[\dA-Za-z]{4,5}$"#, options: .regularExpression) != nil {
                    stockCodes.append(code)
                }
            }
        }
        
        return stockCodes
    }
    
}

#Preview {
    IPOFluctuationRateScreen()
}
