//
//  HomeViewModel.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import Foundation
import Photos

class HomeViewModel: ObservableObject {
    
    var sections: [Section] = [
        .init(type: .largeFiles, totalItems: 15, totalSize: 12939),
        .init(type: .screenshots, totalItems: 3, totalSize: 2344),
        .init(type: .duplicates, totalItems: 15, totalSize: 1920)
    ]
    
    var largeAssets = PHFetchResult<PHAsset>()
    var screenshots = PHFetchResult<PHAsset>()
    let minLargeFileSize = 10_000_000 // KB
    
    init() {
        loadLargeFiles()
    }
    
    func loadLargeFiles() {
        let options = PHFetchOptions()
//        options.predicate = NSPredicate(format: "pixelWidth > %d", minLargeFileSize)
        largeAssets = PHAsset.fetchAssets(with: options)
        print(largeAssets.count)
    }
    
}

extension HomeViewModel {

    enum SectionType {
        case largeFiles
        case screenshots
        case similars
        case duplicates
        
        var title: String {
            switch self {
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
