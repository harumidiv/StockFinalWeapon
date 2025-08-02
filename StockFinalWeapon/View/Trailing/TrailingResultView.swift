//
//  TrailingResultView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/02.
//

import SwiftUI

struct TrailingResultView: View {
    @Binding var stockList: [StockCodeTag]
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var lossCut: Int
    @Binding var profitFixed: Int
    
    var body: some View {
        Section(header: Text("結果")) {
            
            let winOrLostList = stockList.compactMap { $0.winOrLose(start: startDate, end: endDate, profitFixed: profitFixed, lossCut: lossCut)}
            
            let winCount = winOrLostList.filter { $0 == .win }.count
            let loseCount:Double = Double(winOrLostList.filter { $0 == .lose }.count)
            let drawCount = winOrLostList.filter { $0 == .unsettled }.count
            
            Text("勝ち: \(winCount), 負け: \(Int(loseCount)), 未定: \(drawCount), 負け割合: \(String(format: "%.1f", loseCount/Double(stockList.count)))")
            List {
                ForEach($stockList) { stock in
                    HStack {
                        Text(stock.wrappedValue.code)
                        Image(stock.wrappedValue.winOrLose(start: startDate, end: endDate, profitFixed: profitFixed, lossCut: lossCut).image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                    }
                }
            }
        }
    }
}

#Preview {
    TrailingResultView(stockList: .constant([]), startDate: .constant(Date()), endDate: .constant(Date()), lossCut: .constant(-7), profitFixed: .constant(7))
}
