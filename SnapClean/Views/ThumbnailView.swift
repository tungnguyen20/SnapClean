//
//  ThumbnailView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI
import Photos

struct ThumbnailView: View {
    @EnvironmentObject var photoLoader: PhotosLoader
    @State private var image: Image?
    @Binding var isSelected: Bool
    
    var assetLocalId: String
    
    init(assetLocalId: String, isSelected: Binding<Bool>) {
        self.assetLocalId = assetLocalId
        self._isSelected = isSelected
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image = image {
                GeometryReader { proxy in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.width
                        )
                        .clipped()
                }
                .aspectRatio(1, contentMode: .fit)
            } else {
                Rectangle()
                    .foregroundColor(Color.gray100)
                    .aspectRatio(1, contentMode: .fit)
            }
            
            if isSelected {
                Color.gray50
            }
            
            GeometryReader { proxy in
                HStack {
                    Spacer()
                    VStack {
                        VStack {
                            
                        }
                        .frame(width: proxy.size.width / 2, height: proxy.size.height / 2)
                        .overlay(
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isSelected.toggle()
                                }
                        )
                        Spacer()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            
            VStack {
                HStack(alignment: .top) {
                    Text(photoLoader.metadata[assetLocalId]?.sizeOnDisk.displayText ?? "0 KB")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(6)
                        .background(Color.gray34)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button {
                        isSelected.toggle()
                    } label: {
                        if isSelected {
                            Image("checkbox-circle")
                                .frame(width: 20, height: 20)
                        } else {
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: 20, height: 20)
                        }
                    }
                    
                }
                
                Spacer()
                
                if photoLoader.metadata[assetLocalId]?.resource?.type == .video {
                    HStack {
                        Spacer()
                        
                        Image("play-circle")
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(8)
        }
        .task {
            await loadImageAsset()
        }
        .onDisappear {
            image = nil
        }
    }
    
    func loadImageAsset(
        targetSize: CGSize = PHImageManagerMaximumSize
    ) async {
        guard let uiImage = try? await photoLoader
            .fetchImage(
                byLocalIdentifier: assetLocalId,
                targetSize: targetSize
            ) else {
            image = nil
            return
        }
        image = Image(uiImage: uiImage)
    }
}
