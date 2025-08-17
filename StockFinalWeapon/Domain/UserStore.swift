//
//  UserStore.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/07.
//

import Foundation
import SwiftUI

final class UserStore {
    private enum Key: String {
        case january
        case february
        case march
        case april
        case may
        case june
        case july
        case august
        case september
        case october
        case november
        case december
        
        case yuutaiRecordDatePushNotification
    }
    
    static func deleteAllYuutaiInfo() {
        for month in YuutaiMonth.allCases {
            deleteYuutaiInfo(month: month)
        }
        UserDefaults.standard.synchronize()
    }
    
    static func deleteYuutaiInfo(month: YuutaiMonth) {
        switch month {
        case .january:
            UserDefaults.standard.removeObject(forKey: Key.january.rawValue)
        case .february:
            UserDefaults.standard.removeObject(forKey: Key.february.rawValue)
        case .march:
            UserDefaults.standard.removeObject(forKey: Key.march.rawValue)
        case .april:
            UserDefaults.standard.removeObject(forKey: Key.april.rawValue)
        case .may:
            UserDefaults.standard.removeObject(forKey: Key.may.rawValue)
        case .june:
            UserDefaults.standard.removeObject(forKey: Key.june.rawValue)
        case .july:
            UserDefaults.standard.removeObject(forKey: Key.july.rawValue)
        case .august:
            UserDefaults.standard.removeObject(forKey: Key.august.rawValue)
        case .september:
            UserDefaults.standard.removeObject(forKey: Key.september.rawValue)
        case .october:
            UserDefaults.standard.removeObject(forKey: Key.october.rawValue)
        case .november:
            UserDefaults.standard.removeObject(forKey: Key.november.rawValue)
        case .december:
            UserDefaults.standard.removeObject(forKey: Key.december.rawValue)
        }
    }
    
    static func getYuutaiInfo(for month: YuutaiMonth) -> [TanosiiYuutaiInfo]? {
        switch month {
        case .january: return january
        case .february: return february
        case .march: return march
        case .april: return april
        case .may: return may
        case .june: return june
        case .july: return july
        case .august: return august
        case .september: return september
        case .october: return october
        case .november: return november
        case .december: return december
        }
    }
    
    static func setYuutaiInfo(_ data: [TanosiiYuutaiInfo], for month: YuutaiMonth) {
        switch month {
        case .january: january = data
        case .february: february = data
        case .march: march = data
        case .april: april = data
        case .may: may = data
        case .june: june = data
        case .july: july = data
        case .august: august = data
        case .september: september = data
        case .october: october = data
        case .november: november = data
        case .december: december = data
        }
    }
    
    static var yuutaiRecordDatePushNotification: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Key.yuutaiRecordDatePushNotification.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.january.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    private static var january: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.january.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.january.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var february: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.february.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.february.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var march: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.march.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.march.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var april: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.april.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.april.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var may: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.may.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.may.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var june: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.june.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.june.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var july: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.july.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.july.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var august: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.august.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.august.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var september: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.september.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.september.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var october: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.october.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.october.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var november: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.november.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.november.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
    
    private static var december: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.december.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } 
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.december.rawValue)
                UserDefaults.standard.synchronize()
            } 
        }
    }
}

