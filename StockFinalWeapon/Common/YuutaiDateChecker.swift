//
//  YuutaiDateChecker.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/16.
//
import Foundation
import SwiftUI

final class YuutaiDateChecker {
    static func shareholderBenefitEligibleDays(in year: Int) -> [Date] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        
        var result: [Date] = []
        
        for month in 1...12 {
            // 月初
            guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) else {
                continue
            }
            
            // 月末から判定して求める
            var target = lastDay
            while calendar.component(.month, from: target) == month {
                if isShareholderBenefitLastEligibleDay(date: target) {
                    result.append(target)
                    break // 1日見つけたら終了（その月は1日しか存在しない）
                }
                guard let prev = calendar.date(byAdding: .day, value: -1, to: target) else { break }
                target = prev
            }
        }
        
        return result
    }
    
    static func isShareholderBenefitLastEligibleDay(date: Date) -> Bool {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let firstDay = calendar.date(from: comps),
              let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) else {
            fatalError()
        }
        
        // 月末から遡って最終営業日を取得
        var lastBusinessDay = lastDay
        while calendar.isDateInWeekend(lastBusinessDay) || isJapaneseHoliday(date: lastBusinessDay) {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: lastBusinessDay) else {
                return false
            }
            lastBusinessDay = previousDay
        }
        
        // 3. 最終営業日からさらに遡って2営業日前の「権利付き最終日」を計算
        var lastEligibleDay = lastBusinessDay
        var businessDaysCount = 0
        while businessDaysCount < 2 {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: lastEligibleDay) else {
                return false
            }
            lastEligibleDay = previousDay
            if !calendar.isDateInWeekend(lastEligibleDay) && !YuutaiDateChecker.isJapaneseHoliday(date: lastEligibleDay) {
                businessDaysCount += 1
            }
        }
        
        // 4. 渡された日付と計算した権利付き最終日が一致するか判定
        return calendar.isDate(date, inSameDayAs: lastEligibleDay)
    }

    // 簡易的な日本の祝日判定関数
    // FIXME: より正確に出すには祝日法第3条第2項に従い日曜日と被った場合は振替休日にする処理が必要
    private static func isJapaneseHoliday(date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let year = calendar.component(.year, from: date)
        
        let fixedHolidays: Set<DateComponents> = [
            DateComponents(year: year, month: 1, day: 1), // 元日
            DateComponents(year: year, month: 2, day: 11), // 建国記念の日
            DateComponents(year: year, month: 2, day: 23), // 天皇誕生日
            DateComponents(year: year, month: 3, day: 21), // 春分の日　*前後する可能性あり
            DateComponents(year: year, month: 4, day: 29), // 昭和の日
            DateComponents(year: year, month: 5, day: 3), // 憲法記念日
            DateComponents(year: year, month: 5, day: 4), // みどりの日
            DateComponents(year: year, month: 5, day: 5), // こどもの日
            DateComponents(year: year, month: 8, day: 11), // 山の日
            DateComponents(year: year, month: 9, day: 23), // 秋分の日 *前後する可能性あり
            DateComponents(year: year, month: 11, day: 3), // 文化の日
            DateComponents(year: year, month: 11, day: 23), // 勤労感謝の日
            DateComponents(year: year, month: 12, day: 31) // ※ 大納会が30日なので31日は空いていない
        ]
        
        let transformedHolidays: [DateComponents] = [
            findNthMonday(year: year, month: 1, weekNumber: 2), // 成人の日
            findNthMonday(year: year, month: 7, weekNumber: 3), // 海の日
            findNthMonday(year: year, month: 9, weekNumber: 3), // 敬老の日
            findNthMonday(year: year, month: 10, weekNumber: 2) // スポーツの日
        ].compactMap { holiday in
            guard let nonOptionalHoliday = holiday else { return nil }
            return calendar.dateComponents([.year, .month, .day], from: nonOptionalHoliday)
        }
        
        let holidays:Set<DateComponents> = fixedHolidays.union(transformedHolidays)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let targetDay = DateComponents(year: components.year, month: components.month, day: components.day)
        
        let contains = holidays.contains(targetDay)
        
        return contains
    }
    
    /// 指定した年、月、第〇週目の月曜日を返す
    /// - Parameters:
    ///   - year: 取得したい日付の年
    ///   - month: 取得したい日付の月
    ///   - weekNumber: 第何週目か（例：第2週目なら2）
    /// - Returns: 該当する日付 (Date?)
    private static func findNthMonday(year: Int, month: Int, weekNumber: Int) -> Date? {
        let calendar = Calendar.current
        
        // 1. 指定した年と月の1日を取得
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard var date = calendar.date(from: components) else {
            return nil
        }
        
        var mondayCount = 0
        
        // 無限ループを避けるための安全策
        for _ in 0..<31 {
            let weekday = calendar.component(.weekday, from: date)
            
            // 2. 曜日をチェックし、月曜日ならカウンターを増やす
            // .weekdayの戻り値は1=日曜日, 2=月曜日, ..., 7=土曜日
            if weekday == 2 {
                mondayCount += 1
            }
            
            // 3. カウンターが指定の週数と一致したら、その日付を返す
            if mondayCount == weekNumber {
                return date
            }
            
            // 4. 次の日に進める
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else {
                return nil
            }
            date = nextDay
        }
        return nil
    }
}


extension YuutaiDateChecker {
    
    /// 権利付き最終日にローカル通知を行う
    static func scheduleYuutaiLocalNotification() {
        let calender = Calendar.current
        let year = calender.component(.year, from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let list = YuutaiDateChecker.shareholderBenefitEligibleDays(in: year)
        scheduleLocalNotification(dates: list)
    }
    
    private static func scheduleLocalNotification(dates: [Date]) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            
            if granted {
                dates.forEach { date in
                    let calender = Calendar.current
                    let year = calender.component(.year, from: date)
                    let month = calender.component(.month, from: date)
                    let day = calender.component(.day, from: date)
                    let dateComponents = DateComponents(year: year, month: month, day: day, hour: 19)
                    
                    let content = UNMutableNotificationContent()
                    content.title = "優待権利付き最終日"
                    content.body = "現渡しわすれてない？"
                    content.sound = UNNotificationSound.default
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                    
                    let request = UNNotificationRequest(identifier: month.description, content: content, trigger: trigger)
                    
                    UNUserNotificationCenter.current().add(request) { (error) in
                        if let error = error {
                            print("⚠️通知のスケジュールに失敗しました: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                print("⚠️通知の許可が拒否されました。")
            }
        }
    }
}

