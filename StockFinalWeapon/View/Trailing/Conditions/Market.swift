//
//  Market.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/03.
//

import SwiftUI

enum Market: String, CaseIterable, Identifiable {
    case tokyo = "東証"
    case nagoya = "名証"
    case sapporo = "札証"
    case hukuoka = "福証"
    case none = "海外"
    
    var id: Self { self }
    
    var symbol: String {
        switch self {
        case .tokyo:
            return ".T"
        case .nagoya:
            return ".N"
        case .sapporo:
            return ".S"
        case .hukuoka:
            return ".F"
        case .none:
            return ""
        }
    }
    
    var color: Color {
        switch self {
        case .tokyo:
            return .red
        case .nagoya:
            return .yellow
        case .sapporo:
            return .blue
        case .hukuoka:
            return .green
        case .none:
            return .gray
        }
    }
}
