//
//  StockData.swift
//  StockChart
//
//  Created by 佐川 晴海 on 2025/03/18.
//

import SwiftUI

struct StockIPOData: Identifiable {
    enum Market: String {
        case prime = "プライム"
        case standard = "スタンダード"
        case glose = "グロース"
    }

    var id = UUID()
    var dateString: String
    var code: String
    var market: Market
    
    var startDate: Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // フォーマットを指定（年/月/日）
        
        if let date = dateFormatter.date(from: dateString) {
            return date
        } else {
            assertionFailure("失敗したので要素を要確認")
            return Date()
        }
    }
    
    var endDate: Date {
        if let date = businessDaysAgo(from: startDate, days: 7) {
            return date
        } else {
            assertionFailure("失敗したので要素を要確認")
            return Date()
        }
        
    }
    
    private func businessDaysAgo(from date: Date, days: Int) -> Date? {
        let calendar = Calendar.current
        var currentDate = date
        var remainingDays = days
        
        // 平日のみ遡るロジック
        while remainingDays > 0 {
            // 1日後に移動
            guard let previousDate = calendar.date(byAdding: .day, value: +1, to: currentDate) else {
                return nil // 日付計算に失敗した場合
            }
            currentDate = previousDate
            
            // 曜日を確認 (土日でない場合のみカウント)
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday != 1 && weekday != 7 { // 1: 日曜日, 7: 土曜日
                remainingDays -= 1
            }
        }
        
        return currentDate
    }
}
