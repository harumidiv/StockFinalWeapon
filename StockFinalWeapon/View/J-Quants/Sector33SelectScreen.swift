//
//  Sector33SelectScreen.swift
//  StockFinalWeapon
//
//  Created by Harumi Sagawa on 2026/02/08.
//

import SwiftUI

struct Sector33SelectScreen: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    @State private var sectors: [Sector33] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var path = NavigationPath()

    let apiClient = APIClient()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("業種データを取得中...")
                            .foregroundColor(.secondary)
                    }
                } else if let errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("エラー")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    Form {
                        Section(header: Text("33業種から選択")) {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(sectors) { sector in
                                    Button(action: {
                                        path.append(sector)
                                    }) {
                                        Text(sector.name)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, minHeight: 60)
                                            .background(Color(.tertiarySystemBackground))
                                            .cornerRadius(8)
                                            .foregroundColor(.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("業種選択")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Sector33.self) { sector in
                JQuantsScreen(selectedSector: sector)
            }
        }
        .task {
            await loadSectors()
        }
    }

    private func loadSectors() async {
        isLoading = true
        errorMessage = nil

        let email = "harumi.hobby@gmail.com"
        let password = "A7kL9mQ2R8sT"

        do {
            let authClient = AuthClient(client: apiClient)
            let stockClient = StockClient(client: apiClient)

            let refreshToken = try await authClient.fetchRefreshToken(mail: email, password: password)
            let idToken = try await authClient.fetchIdToken(refreshToken: refreshToken)

            let stockList = try await stockClient.fetchListedInfo(idToken: idToken)

            sectors = Sector33.extractFrom(listedInfo: stockList)
            isLoading = false

            print("取得した業種数: \(sectors.count)")

        } catch {
            print("エラーが発生しました: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    Sector33SelectScreen()
}
