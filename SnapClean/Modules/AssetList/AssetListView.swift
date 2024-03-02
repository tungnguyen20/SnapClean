//
//  AssetListView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI
import Photos

struct AssetListView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var photoLoader: PhotosLoader
    @StateObject var viewModel = AssetListViewModel()
    var category: AssetCategory
    
    init(category: AssetCategory) {
        self.category = category
    }
    
    var sections: [AssetSection] {
        switch category {
        case .all:
            return photoLoader.allAssets
        case .largeFiles:
            return photoLoader.largeAssets
        case .screenshots:
            return photoLoader.screenshots
        case .duplicates:
            return photoLoader.duplicatedPhotos
        case .similars:
            return photoLoader.similarPhotos
        }
    }
    
    var totalItems: Int {
        return sections.reduce(0, { $0 + $1.assets.count })
    }
    
    var totalItemSize: Float {
        switch category {
        case .all:
            return photoLoader.allAssetsSize
        case .largeFiles:
            return photoLoader.largeAssetsSize
        case .similars:
            return photoLoader.similarPhotosSize
        case .duplicates:
            return photoLoader.duplicatedPhotosSize
        case .screenshots:
            return photoLoader.screenshotsSize
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Image(systemName: "chevron.left")
                    })
                    
                    Spacer()
                }
                .padding(16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    
                    HStack {
                        Text("\(totalItems) items • \(totalItemSize.displayText)")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.textSecondary)
                        
                        Spacer()
                        
                        Button {
                            
                        } label: {
                            HStack(spacing: 2) {
                                Image("filter-lines")
                                Text("Newest")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
                Divider()
                
                GeometryReader { proxy in
                    List {
                        ForEach(sections, id: \.id) { section in
                            createAssetsSectionView(width: proxy.size.width, section: section)
                                .buttonStyle(PlainButtonStyle())
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .padding(.zero)
                }
            }
            
            if viewModel.totalSelectedItems > 0 {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected \(viewModel.totalSelectedItems) items")
                            .foregroundStyle(Color.textPrimary)
                            .font(.system(size: 17, weight: .semibold))
                        Text("\(viewModel.totalSelectedItemsSize.displayText) freed after cleaning")
                            .foregroundStyle(Color.textSecondary)
                            .font(.system(size: 15))
                    }
                    
                    Spacer()
                    
                    Image("trash")
                        .padding()
                        .background(Color.brand)
                        .clipShape(Circle())
                }
                .padding(16)
                .background(Color.white.shadow(color: .black, radius: 10, y: 5))
                .clipShape(Capsule())
                .padding(16)
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
            
        }
        .onAppear {
            viewModel.setup(photoLoader: photoLoader)
        }
    }
    
    @ViewBuilder
    func createThumbnailView(asset: PHAsset) -> some View {
        DetailThumbnailView(assetLocalId: asset.localIdentifier, isSelected: Binding<Bool>(
            get: {
                return viewModel.selectingLocalIds.contains(asset.localIdentifier)
            },
            set: { isSelected in
                withAnimation {
                    if isSelected {
                        viewModel.selectingLocalIds.insert(asset.localIdentifier)
                    } else {
                        viewModel.selectingLocalIds.remove(asset.localIdentifier)
                    }
                }
            }
        ))
    }
    
    @ViewBuilder
    func createFocusGrid(width: CGFloat, assets: [PHAsset]) -> some View {
        if assets.count < 3 {
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: 1), count: 3),
                spacing: 1
            ) {
                ForEach(assets, id: \.self) { asset in
                    createThumbnailView(asset: asset)
                }
            }
        } else {
            HStack(spacing: 1) {
                createThumbnailView(asset: assets[0])
                    .frame(width: (width - 1) * 2/3, height: (width - 1) * 2/3)
                
                VStack(spacing: 1) {
                    createThumbnailView(asset: assets[1])
                    createThumbnailView(asset: assets[2])
                }
            }
            .padding(.zero)
            
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: 1), count: 3),
                spacing: 1
            ) {
                ForEach(3..<assets.count, id: \.self) { index in
                    createThumbnailView(asset: assets[index])
                }
            }
        }
    }
    
    @ViewBuilder
    func createNormalGrid(width: CGFloat, assets: [PHAsset]) -> some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 1), count: 3),
            spacing: 1
        ) {
            ForEach(assets, id: \.self) { asset in
                createThumbnailView(asset: asset)
                    .frame(width: width / 3, height: width / 2)
            }
        }
    }
    
    @ViewBuilder
    func createHorizontalRectList(width: CGFloat, assets: [PHAsset]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(assets, id: \.self) { asset in
                    createThumbnailView(asset: asset)
                        .frame(width: width / 3.3, height: width / 3.3 * 1.5)
                }
            }
        }
    }
    
    @ViewBuilder
    func createHorizontalSquareList(width: CGFloat, assets: [PHAsset]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 1) {
                ForEach(assets, id: \.self) { asset in
                    createThumbnailView(asset: asset)
                        .frame(width: width / 3.3, height: width / 3.3)
                }
            }
        }
    }
    
    @ViewBuilder
    func createAssetsSectionView(width: CGFloat, section: AssetSection) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(section.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
                
                Button {
                    section.assets.forEach { asset in
                        viewModel.selectingLocalIds.insert(asset.localIdentifier)
                    }
                } label: {
                    Text("Select all")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            switch section.style {
            case .focusGrid:
                createFocusGrid(width: width, assets: section.assets)
            case .normalGrid:
                createNormalGrid(width: width, assets: section.assets)
            case .horizontalRect:
                createHorizontalRectList(width: width, assets: section.assets)
            case .horizontalSquare:
                createHorizontalSquareList(width: width, assets: section.assets)
            }
        }
    }
    
}
