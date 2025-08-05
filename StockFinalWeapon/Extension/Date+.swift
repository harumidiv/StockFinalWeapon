//
//  Date+.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//


import Foundation

// Date extension extracted from WinningRateScreen.swift
extension Date {
    /// "MM/dd" 形式の文字列を返す
    var monthDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    /// 同じ年かの判定
    func isSameYear(as otherDate: Date, calendar: Calendar = .current) -> Bool {
        let year1 = calendar.component(.year, from: self)
        let year2 = calendar.component(.year, from: otherDate)
        return year1 == year2
    }
}
