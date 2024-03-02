//
//  AssetCategory.swift
//  SnapClean
//
//  Created by Tung Nguyen on 29/02/2024.
//

import Foundation

enum AssetCategory: String, Identifiable {
    typealias ObjectIdentifier = String
    var id: ObjectIdentifier {
        rawValue
    }
    
    case all
    case largeFiles
    case screenshots
    case similars
    case duplicates
    
    var title: String {
        switch self {
        case .all:
            return "All files"
        case .largeFiles:
            return "Large files"
        case .screenshots:
            return "Screenshots"
        case .similars:
            return "Similars"
        case .duplicates:
            return "Duplicates"
        }
    }
}
