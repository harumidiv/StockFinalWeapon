//
//  DisabledView.swift
//  StockFinalWeapon
//
//  Created by 佐川 晴海 on 2025/08/09.
//


import SwiftUI

// MARK: - DisabledView

public struct DisabledView: View {
    public var body: some View {
        Color.white.opacity(0.00001)
    }
}

// MARK: - ActivityIndicatorView

private struct ActivityIndicatorView: UIViewRepresentable {
    var color: UIColor?

    func makeUIView(context: UIViewRepresentableContext<ActivityIndicatorView>) -> UIActivityIndicatorView {
        UIActivityIndicatorView(style: .large)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicatorView>) {
        uiView.color = color
        uiView.startAnimating()
    }
}

// MARK: - ActivityIndicator

public struct ActivityIndicator: View {
    public var body: some View {
        ActivityIndicatorView(color: .gray)
            .padding()
    }

    public init() {
    }
}

public extension View {
    func loading(_ show: Bool, disabled: Bool = true) -> some View {
        ZStack {
            self
            if show {
                if disabled {
                    DisabledView()
                }
                ActivityIndicator()
            }
        }
    }

    func loadingFullScreen(_ show: Bool) -> some View {
        fullScreenCover(isPresented: .constant(show)) {
            ActivityIndicator()
                .background(BackgroundCleanerView())
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
    }
}


// MARK: - ActivityIndicator_Previews

#Preview {
    VStack {
        List {
            ForEach(1..<20) { num in
                Button("Button \(num)", action: {})
            }
        }
        .toolbar {
            ToolbarItem {
                Button("navi", action: {})
            }
            ToolbarItem(placement: .bottomBar) {
                Button("bottom", action: {})
            }
        }
        .navigationTitle("dummy")
    }
    .loading(true)
}
