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
    let stockCount: Int

    init(code: String, name: String, stockCount: Int = 0) {
        self.id = code
        self.code = code
        self.name = name
        self.stockCount = stockCount
    }

    /// 業種に応じたSFシンボルアイコンを返す
    var icon: String {
        switch name {
        case let n where n.contains("水産") || n.contains("農林"):
            return "leaf.fill"
        case let n where n.contains("鉱業"):
            return "mountain.2.fill"
        case let n where n.contains("建設"):
            return "hammer.fill"
        case let n where n.contains("食料品"):
            return "fork.knife"
        case let n where n.contains("繊維"):
            return "tshirt.fill"
        case let n where n.contains("パルプ") || n.contains("紙"):
            return "doc.text.fill"
        case let n where n.contains("化学"):
            return "flask.fill"
        case let n where n.contains("医薬品"):
            return "cross.case.fill"
        case let n where n.contains("石油") || n.contains("石炭"):
            return "fuelpump.fill"
        case let n where n.contains("ゴム"):
            return "circle.grid.cross.fill"
        case let n where n.contains("ガラス") || n.contains("土石"):
            return "square.on.square"
        case let n where n.contains("鉄鋼"):
            return "cube.fill"
        case let n where n.contains("非鉄金属"):
            return "bolt.fill"
        case let n where n.contains("金属製品"):
            return "wrench.and.screwdriver.fill"
        case let n where n.contains("機械"):
            return "gearshape.2.fill"
        case let n where n.contains("電気機器"):
            return "bolt.circle.fill"
        case let n where n.contains("輸送用機器"):
            return "car.fill"
        case let n where n.contains("精密機器"):
            return "camera.fill"
        case let n where n.contains("その他製品"):
            return "shippingbox.fill"
        case let n where n.contains("電気") || n.contains("ガス"):
            return "lightbulb.fill"
        case let n where n.contains("陸運"):
            return "bus.fill"
        case let n where n.contains("海運"):
            return "ferry.fill"
        case let n where n.contains("空運"):
            return "airplane"
        case let n where n.contains("倉庫") || n.contains("運輸"):
            return "archivebox.fill"
        case let n where n.contains("情報") || n.contains("通信"):
            return "antenna.radiowaves.left.and.right"
        case let n where n.contains("卸売"):
            return "cart.fill"
        case let n where n.contains("小売"):
            return "bag.fill"
        case let n where n.contains("銀行"):
            return "building.columns.fill"
        case let n where n.contains("証券") || n.contains("商品先物"):
            return "chart.line.uptrend.xyaxis"
        case let n where n.contains("保険"):
            return "shield.fill"
        case let n where n.contains("金融"):
            return "yensign.circle.fill"
        case let n where n.contains("不動産"):
            return "house.fill"
        case let n where n.contains("サービス"):
            return "person.2.fill"
        default:
            return "building.2.fill"
        }
    }

    /// ListedInfoの配列から33業種を抽出（銘柄数をカウント）
    static func extractFrom(listedInfo: [ListedInfo]) -> [Sector33] {
        var sectorMap: [String: String] = [:]
        var sectorCount: [String: Int] = [:]

        // 市場フィルタ条件（プライム、スタンダード、グロースのみ）
        let validMarketCodes = ["0111", "0112", "0113"]

        for info in listedInfo {
            // 9999（ETF・その他）、sector17が99、対象外市場を除外
            if info.sector33Code != "9999" &&
               info.sector17Code != "99" &&
               validMarketCodes.contains(info.marketCode) {
                sectorMap[info.sector33Code] = info.sector33CodeName
                sectorCount[info.sector33Code, default: 0] += 1
            }
        }

        // コード順にソートして返す
        return sectorMap
            .map { Sector33(code: $0.key, name: $0.value, stockCount: sectorCount[$0.key] ?? 0) }
            .sorted { $0.code < $1.code }
    }
}
