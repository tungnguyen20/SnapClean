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

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
