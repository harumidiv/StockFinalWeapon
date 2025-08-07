//
//  UserStore.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/07.
//

import Foundation

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
    }
    
    static var january: [TanosiiYuutaiInfo]? {
        get {
            if let data = UserDefaults.standard.data(forKey: Key.january.rawValue) {
                let decoder = JSONDecoder()
                if let infos = try? decoder.decode([TanosiiYuutaiInfo].self, from: data) {
                    return infos
                }
            } else {
                print("😺: 失敗")
            }
            return nil
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: Key.january.rawValue)
                UserDefaults.standard.synchronize()
            } else {
                print("😺: 保存エラー")
            }
        }
    }
    
    static var february: [String] {
        get {
            guard let february = UserDefaults.standard.array(forKey: Key.february.rawValue) as? [String] else {
                return []
            }
            return february
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.february.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var march: [String] {
        get {
            guard let march = UserDefaults.standard.array(forKey: Key.march.rawValue) as? [String] else {
                return []
            }
            return march
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.march.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var april: [String] {
        get {
            guard let april = UserDefaults.standard.array(forKey: Key.april.rawValue) as? [String] else {
                return []
            }
            return april
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.april.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var may: [String] {
        get {
            guard let may = UserDefaults.standard.array(forKey: Key.may.rawValue) as? [String] else {
                return []
            }
            return may
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.may.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var june: [String] {
        get {
            guard let june = UserDefaults.standard.array(forKey: Key.june.rawValue) as? [String] else {
                return []
            }
            return june
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.june.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var july: [String] {
        get {
            guard let july = UserDefaults.standard.array(forKey: Key.july.rawValue) as? [String] else {
                return []
            }
            return july
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.july.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var august: [String] {
        get {
            guard let august = UserDefaults.standard.array(forKey: Key.august.rawValue) as? [String] else {
                return []
            }
            return august
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.august.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var september: [String] {
        get {
            guard let september = UserDefaults.standard.array(forKey: Key.september.rawValue) as? [String] else {
                return []
            }
            return september
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.september.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var october: [String] {
        get {
            guard let october = UserDefaults.standard.array(forKey: Key.october.rawValue) as? [String] else {
                return []
            }
            return october
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.october.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var november: [String] {
        get {
            guard let november = UserDefaults.standard.array(forKey: Key.november.rawValue) as? [String] else {
                return []
            }
            return november
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.november.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var december: [String] {
        get {
            guard let december = UserDefaults.standard.array(forKey: Key.december.rawValue) as? [String] else {
                return []
            }
            return december
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.december.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
}
