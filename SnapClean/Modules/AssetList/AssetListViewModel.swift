//
//  AssetListViewModel.swift
//  SnapClean
//
//  Created by Tung Nguyen on 29/02/2024.
//

import Foundation
import Combine

class AssetListViewModel: ObservableObject {
    @Published var selectingLocalIds: Set<String> = .init()
    @Published var totalSelectedItems: Int = 0
    @Published var totalSelectedItemsSize: Float = 0
    var sections: [AssetSection] = []
    var cancellables = Set<AnyCancellable>()
    var photoManager: PhotoManager?
    
    init() {
        $selectingLocalIds
            .sink { localIds in
                self.totalSelectedItems = localIds.count
                self.totalSelectedItemsSize = localIds.reduce(0, { $0 + (self.photoManager?.sizeOnDisk(assetLocalId: $1) ?? 0) })
            }
            .store(in: &cancellables)
        
    }
    
    func setup(photoManager: PhotoManager) {
        self.photoManager = photoManager
    }
}
