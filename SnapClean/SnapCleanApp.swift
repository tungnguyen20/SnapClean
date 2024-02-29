//
//  SnapCleanApp.swift
//  SnapClean
//
//  Created by Tung Nguyen on 26/02/2024.
//

import SwiftUI

@main
struct SnapCleanApp: App {
    let persistenceController = PersistenceController.shared
    let photoLoader = PhotosLoader()
    @State var isLoadingCompleted: Bool = false

    var body: some Scene {
        WindowGroup {
            NavigationView {
                NavigationLink(isActive: $isLoadingCompleted) {
                    HomeView()
                        .navigationBarHidden(true)
                        .environmentObject(photoLoader)
                } label: {
                    ProgressView()
                        .background(Image("bg"))
                        .navigationBarHidden(true)
                        .onAppear {
                            Task {
                                await photoLoader.load()
                                isLoadingCompleted = true
                            }
                        }
                }
            }
        }
    }
}
