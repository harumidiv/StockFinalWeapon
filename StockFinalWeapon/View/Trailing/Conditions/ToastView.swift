//
//  ToastView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/06.
//

import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding()
            .background(Color.red)
            .cornerRadius(8)
            .padding(.horizontal, 16)
    }
}
