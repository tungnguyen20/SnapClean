//
//  PhotosLoader.swift
//  SnapClean
//
//  Created by Tung Nguyen on 27/02/2024.
//

import Foundation
import Photos
import UIKit
import Vision

struct AssetMetadata {
    var resource: PHAssetResource?
    var featurePrint: VNFeaturePrintObservation?
    
    var sizeOnDisk: Float {
        if let fileSize = resource?.value(forKey: "fileSize") as? Float {
            return fileSize
        }
        return 0
    }
}

class PhotosLoader: ObservableObject {
    var imageCachingManager = PHCachingImageManager()
    var allAssets: PHFetchResultCollection?
    var metadata: [String: AssetMetadata] = [:]
    var largeAssets: [AssetSection] = []
    
    init() {}
    
    func load() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [.init(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        allAssets = PHFetchResultCollection(fetchResult: result)
        
        if let allAssets {
            metadata = await fetchAssetsMetadata(assets: allAssets)
            largeAssets = fetchAssetsGroupByDate(fetchResult: result)
        }
    }
    
    func fetchAssetsMetadata(assets: PHFetchResultCollection) async -> [String: AssetMetadata] {
        return await withTaskGroup(of: (String, AssetMetadata?).self, returning: [String: AssetMetadata].self) { taskGroup in
            for asset in assets {
                taskGroup.addTask { await self.fetchMetadata(asset: asset) }
            }
            
            var data = [String: AssetMetadata]()
            for await result in taskGroup {
                data[result.0] = result.1
            }
            return data
        }
    }
    
    func featurePrintForImage(image: UIImage) -> VNFeaturePrintObservation? {
        let requestHandler = VNImageRequestHandler(
            cgImage: image.cgImage!,
            options: [:]
        )
        do {
            let request = VNGenerateImageFeaturePrintRequest()
            try requestHandler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }
    
    func fetchMetadata(asset: PHAsset) async -> (String, AssetMetadata?) {
        let resource = PHAssetResource.assetResources(for: asset).first
        return (asset.localIdentifier, .init(resource: resource, featurePrint: nil))
//        let image = try? await fetchImage(byLocalIdentifier: asset.localIdentifier, targetSize: .init(width: 100, height: 100))
//        guard let image = image else {
//            print("NO IMAGE", Date().timeIntervalSince(date))
//            return (asset.localIdentifier, .init(resource: resource, featurePrint: nil))
//        }
//        let featurePrint = featurePrintForImage(image: image)
//        print("IMAGE", Date().timeIntervalSince(date))
//        return (asset.localIdentifier, AssetMetadata(resource: resource, featurePrint: featurePrint))
    }
    
    func fetchAssetsGroupByDate(fetchResult: PHFetchResult<PHAsset>) -> [AssetSection] {
        let largeAssets = PHFetchResultCollection(fetchResult: fetchResult)
        let groups = Dictionary(grouping: largeAssets) { element in
            return Calendar.current.startOfDay(for: element.creationDate ?? Date())
        }
        let sections = groups.keys.sorted(by: >).map { date in
            let options = PHFetchOptions()
            let nextDate = Calendar.current.date(byAdding: .init(day: 1), to: date)!
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", date as NSDate, nextDate as NSDate)
            let assets = PHAsset.fetchAssets(with: options)
            return AssetSection(
                title: date.displayText,
                assets: PHFetchResultCollection(fetchResult: assets).sorted(by: { lhs, rhs in
                    return (metadata[lhs.localIdentifier]?.sizeOnDisk ?? 0) > (metadata[rhs.localIdentifier]?.sizeOnDisk ?? 0)
                }),
                style: .focusGrid
            )
        }
        return sections
    }
    
    func fetchImage(
        byLocalIdentifier localId: String,
        targetSize: CGSize = PHImageManagerMaximumSize,
        contentMode: PHImageContentMode = .default
    ) async throws -> UIImage? {
        let results = PHAsset.fetchAssets(
            withLocalIdentifiers: [localId],
            options: nil
        )
        guard let asset = results.firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.imageCachingManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options,
                resultHandler: { image, info in
                    if let error = info?[PHImageErrorKey] as? Error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: image)
                }
            )
        }
    }
    
}
