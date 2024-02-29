//
//  AssetListView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI
import Photos

struct DefaultAssetListView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var photoLoader: PhotosLoader
    @State var selectingLocalIds: Set<String> = .init()
    
    var body: some View {
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
                Text("Large items")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                
                HStack {
                    Text("320 items • 3.2 GB")
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
                    ForEach(photoLoader.largeAssets, id: \.title) { section in
                        createAssetsSectionView(section: section)
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .padding(.zero)
            }
        }
    }
    
    @ViewBuilder
    func createThumbnailView(asset: PHAsset) -> some View {
        ThumbnailView(assetLocalId: asset.localIdentifier, isSelected: Binding<Bool>(
            get: {
                return selectingLocalIds.contains(asset.localIdentifier)
            },
            set: { isSelected in
                if isSelected {
                    selectingLocalIds.insert(asset.localIdentifier)
                } else {
                    selectingLocalIds.remove(asset.localIdentifier)
                }
            }
        ))
    }
    
    @ViewBuilder
    func createFocusGrid(assets: [PHAsset]) -> some View {
        GeometryReader { proxy in
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
                        .frame(width: (proxy.size.width - 1) * 2/3, height: (proxy.size.width - 1) * 2/3)
                    
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
    }
    
    @ViewBuilder
    func createNormalGrid(assets: [PHAsset]) -> some View {
        GeometryReader { proxy in
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: 1), count: 3),
                spacing: 1
            ) {
                ForEach(assets, id: \.self) { asset in
                    createThumbnailView(asset: asset)
                        .frame(width: proxy.size.width / 3, height: proxy.size.width / 2)
                }
            }
        }
    }
    
    @ViewBuilder
    func createHorizontalList(assets: [PHAsset]) -> some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        createThumbnailView(asset: asset)
                            .frame(width: proxy.size.width / 1.5, height: proxy.size.height)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func createAssetsSectionView(section: AssetSection) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(section.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
                
                Button {
                    
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
                createFocusGrid(assets: section.assets)
            case .normalGrid:
                createNormalGrid(assets: section.assets)
            case .horizontal:
                createHorizontalList(assets: section.assets)
            }
        }
    }
}
