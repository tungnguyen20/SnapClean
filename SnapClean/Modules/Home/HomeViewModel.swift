//
//  HomeViewModel.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import Foundation

class HomeViewModel: ObservableObject {
    
    var sections: [Section] = [
        .init(type: .largeFiles, totalItems: 15, totalSize: 12939),
        .init(type: .screenshots, totalItems: 3, totalSize: 2344),
        .init(type: .duplicates, totalItems: 15, totalSize: 1920)
    ]
    
    init() {
 
    }
    
}

extension HomeViewModel {

    enum SectionType {
        case largeFiles
        case screenshots
        case duplicates
        
        var title: String {
            switch self {
            case .largeFiles:
                return "Large files"
            case .screenshots:
                return "Screenshots"
            case .duplicates:
                return "Duplicates"
            }
        }
    }
    
    struct Section: Identifiable {
        typealias ObjectIdentifier = SectionType
        var type: SectionType
        var totalItems: Int
        var totalSize: Double
        
        var id: ObjectIdentifier {
            return type
        }
    }
    
}
