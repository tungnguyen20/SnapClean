//
//  ThumbnailView.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import SwiftUI
import Photos

struct ThumbnailView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var image: Image?
    var assetLocalId: String
    @State var requestID: PHImageRequestID?
    
    init(assetLocalId: String) {
        self.assetLocalId = assetLocalId
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let image = image {
                    GeometryReader { proxy in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: proxy.size.width,
                                height: proxy.size.height
                            )
                            .clipped()
                    }
                } else {
                    Rectangle()
                        .foregroundColor(Color.gray100)
                }
            }
            .task {
                await loadImageAsset(targetSize: proxy.size)
            }
            .onDisappear {
                image = nil
                photoManager.cancelRequest(assetLocalId: assetLocalId)
            }
        }
    }
    
    func loadImageAsset(
        targetSize: CGSize = PHImageManagerMaximumSize
    ) async {
        guard let uiImage = try? await photoManager
            .fetchImage(
                byLocalIdentifier: assetLocalId,
                targetSize: targetSize
            ) else {
            image = nil
            photoManager.removeRequest(assetLocalId: assetLocalId)
            return
        }
        photoManager.removeRequest(assetLocalId: assetLocalId)
        image = Image(uiImage: uiImage)
    }
}
