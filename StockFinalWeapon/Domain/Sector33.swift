//
//  Sector33.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2026/02/08.
//

import Foundation

struct Sector33: Identifiable, Hashable, Codable {
    let id: String
    let code: String
    let name: String

    init(code: String, name: String) {
        self.id = code
        self.code = code
        self.name = name
    }

    /// ListedInfoの配列から33業種を抽出
    static func extractFrom(listedInfo: [ListedInfo]) -> [Sector33] {
        var sectorMap: [String: String] = [:]

        for info in listedInfo {
            // 9999（ETF・その他）は除外
            if info.sector33Code != "9999" {
                sectorMap[info.sector33Code] = info.sector33CodeName
            }
        }

        // コード順にソートして返す
        return sectorMap
            .map { Sector33(code: $0.key, name: $0.value) }
            .sorted { $0.code < $1.code }
    }
}
