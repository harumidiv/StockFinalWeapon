//
//  SafariView.swift
//
//
//  Created by 佐川 晴海 on 2024/04/25.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    typealias UIViewControllerType = SFSafariViewController
    typealias Configuration = SFSafariViewController.Configuration

    private let url: URL
    private let configuration: Configuration?

    init(url: URL, configuration: Configuration? = nil) {
        self.url = url
        self.configuration = configuration
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController: SFSafariViewController
        if let configuration {
            safariViewController = SFSafariViewController(url: url, configuration: configuration)
        } else {
            safariViewController = SFSafariViewController(url: url)
        }
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}

struct OpenURLInSafariViewModifier: ViewModifier {
    @State private var url: URL? = nil
    private var isPresented: Binding<Bool> {
        Binding {
            url != nil
        } set: { newValue in
            if newValue == false {
                url = nil
            }
        }
    }

    private let configuration: SafariView.Configuration?

    init(configuration: SafariView.Configuration?) {
        self.configuration = configuration
    }

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                switch url.scheme {
                case "https"?, "http"?:
                    self.url = url
                    return .handled
                default:
                    return .systemAction(url)
                }
            })
            .fullScreenCover(isPresented: isPresented) {
                if let url {
                    SafariView(url: url, configuration: configuration)
                        .edgesIgnoringSafeArea(.all)
                }
            }

    }
}

extension View {
   func openURLInSafariView(configuration: SafariView.Configuration? = nil) -> some View {
        return modifier(OpenURLInSafariViewModifier(configuration: configuration))
    }
}
