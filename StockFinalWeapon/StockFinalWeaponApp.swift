//
//  StockFinalWeaponApp.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/07/27.
//

import SwiftUI
import SwiftData

@main
struct StockFinalWeaponApp: App {
    var body: some Scene {
        WindowGroup {
            HomeTabView()
                .modelContainer(for: YuutaiSakimawariChartModel.self)
        }
    }
}
