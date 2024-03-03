//
//  SnapCleanApp.swift
//  SnapClean
//
//  Created by Tung Nguyen on 26/02/2024.
//

import SwiftUI
import Photos

@main
struct SnapCleanApp: App {
    let photoManager = PhotoManager()
    @State var isLoadingCompleted: Bool = false

    var body: some Scene {
        WindowGroup {
            NavigationView {
                NavigationLink(isActive: $isLoadingCompleted) {
                    HomeView()
                        .navigationBarHidden(true)
                        .environmentObject(photoManager)
                } label: {
                    ProgressView()
                        .background(Image("bg"))
                        .navigationBarHidden(true)
                        .onAppear {
                            PHPhotoLibrary.requestAuthorization(for: .readWrite) { (status) in
                                switch status {
                                case .authorized:
                                    DispatchQueue.main.async {
                                        isLoadingCompleted = true
                                    }
                                default:
                                    ()
                                }
                            }
                        }
                }
            }
        }
    }
}
