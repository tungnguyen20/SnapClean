//
//  Int+.swift
//  SnapClean
//
//  Created by Tung Nguyen on 29/02/2024.
//

import Foundation

extension Float {
    
    var displayText: String {
        let gb = self / (1024 * 1024 * 1024)
        if gb >= 1 {
            return String(format: "%0.2f GB", gb)
        }
        let mb = self / (1024 * 1024)
        if mb >= 1 {
            return String(format: "%0.2f MB", mb)
        }
        let kb = self / 1024
        return String(format: "%0.2f KB", kb)
    }
    
}
