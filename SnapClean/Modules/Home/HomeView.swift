//
//  HomeView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI
import Photos

struct HomeView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State var selectedCategory: AssetCategory?
    
    var categories: [AssetCategory] = [.all, .largeFiles, .screenshots, .similars, .duplicates]
    
    var body: some View {
        VStack {
            HStack {
                Text("SnapClean")
                    .font(Font.system(size: 24, weight: .bold))
                Spacer()
                Image("setting")
            }
            
            ScrollView(showsIndicators: false) {
                VStack {
                    ForEach(categories) { category in
                        NavigationLink {
                            AssetListView(category: category)
                                .navigationBarHidden(true)
                                .environmentObject(photoManager)
                        } label: {
                            HomeSectionView(category: category)
                                .frame(maxWidth: .infinity)
                                .environmentObject(photoManager)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Image("bg"))
        .task {
            photoManager.fetchAllAssets()
            await photoManager.loadOtherCategories()
        }
    }
}

struct HomeSectionView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State var showDetail: Bool = false
    var category: AssetCategory
    
    var sections: [AssetSection] {
        switch category {
        case .all:
            return photoManager.allAssets
        case .largeFiles:
            return photoManager.largeAssets
        case .screenshots:
            return photoManager.screenshots
        case .duplicates:
            return photoManager.duplicatedPhotos
        case .similars:
            return photoManager.similarPhotos
        }
    }
    
    var totalItems: Int {
        return sections.reduce(0, { $0 + $1.assets.count })
    }
    
    var totalItemSize: Float {
        switch category {
        case .all:
            return photoManager.allAssetsSize
        case .largeFiles:
            return photoManager.largeAssetsSize
        case .similars:
            return photoManager.similarPhotosSize
        case .duplicates:
            return photoManager.duplicatedPhotosSize
        case .screenshots:
            return photoManager.screenshotsSize
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("\(totalItems) items • \(totalItemSize.displayText)")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text("Review")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.brand)
                    .padding(16)
                    .background(Color.gray100)
                    .clipShape(Capsule())
            }
            createGrid(width: UIScreen.main.bounds.width - 64, category: category)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.vertical, 16)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    func createGrid(width: CGFloat, category: AssetCategory) -> some View {
        let assets: [PHAsset] = {
            switch category {
            case .all:
                return photoManager.allAssets.flatMap(\.assets)
            case .largeFiles:
                return photoManager.largeAssets.flatMap(\.assets)
            case .screenshots:
                return photoManager.screenshots.flatMap(\.assets)
            case .similars:
                return photoManager.similarPhotos.flatMap(\.assets)
            case .duplicates:
                return photoManager.duplicatedPhotos.flatMap(\.assets)
            }
        }()
        let itemsPerRow = category == .largeFiles ? 3 : 4
        let maxItems = category == .largeFiles ? 6 : 4
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 4), count: itemsPerRow),
            spacing: 2
        ) {
            ForEach(Array(assets.enumerated().prefix(maxItems)), id: \.offset) { index, asset in
                ZStack {
                    ThumbnailView(assetLocalId: asset.localIdentifier)
                        .frame(width: width / CGFloat(itemsPerRow), height: width / CGFloat(itemsPerRow))
                    
                    if index == maxItems - 1, assets.count - maxItems > 0 {
                        Color.gray50
                        Text("+\(assets.count - maxItems)")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.white)
                    }
                }
            }
        }
    }
}
