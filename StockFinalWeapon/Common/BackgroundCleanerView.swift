//
//  BackgroundCleanerView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/09.
//

import SwiftUI

struct BackgroundCleanerView: UIViewRepresentable {
    var backgroundColor: UIColor? = .clear

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = backgroundColor
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
