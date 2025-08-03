//
//  ChipView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/02.
//

import SwiftUI

struct ChipView: View {
    let stockCodeTag: StockCodeTag
    
    var body: some View {
        HStack(spacing: 10) {
            if let market = stockCodeTag.market.rawValue.first {
                Text(String(market))
                    .foregroundColor(.white)
            }

            Text(stockCodeTag.code)
                .font(.callout)
                .foregroundColor(.white)
                .foregroundStyle(Color.primary)
            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            ZStack {
                Capsule()
                    .fill(stockCodeTag.market.color)
            }
        }
    }
}

#Preview {
    ChipView(stockCodeTag: .init(code: "2432", market: .tokyo, chartData: []))
}
