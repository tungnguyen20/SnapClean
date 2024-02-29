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
import CommonCrypto

struct PHAssetMetadata: Codable {
    var sizeOnDisk: Float
    var isVideo: Bool
}

extension PHAssetResource {
    
    var sizeOnDisk: Float {
        return (value(forKey: "fileSize") as? Float) ?? 0
    }
    
}

class PhotosLoader: ObservableObject {
    var imageCachingManager = PHCachingImageManager()
    let imageManager = PHImageManager.default()
    var allAssets: PHFetchResultCollection?
    var largeAssets: [AssetSection] = []
    var screenshots: [AssetSection] = []
    var duplicatedPhotos: [AssetSection] = []
    let assetResourceCache = Cache<String, PHAssetMetadata>()
    var assetMd5: [String: [UInt8]] = [:]
    
    init() {
        
    }
    
    func load() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [.init(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        allAssets = PHFetchResultCollection(fetchResult: result)
        
        if let allAssets {
            fetchAssetsMetadata(assets: allAssets)
            try? assetResourceCache.saveToDisk(with: "metadata")
            await fetchAssetsMd5()
//            try? assetMd5.saveToDisk(with: "md5")
            largeAssets = fetchAssetsGroupByDate(fetchResult: result)
            screenshots = await fetchScreenshots()
//            duplicatedPhotos = await fetchDuplicatedPhotos()
        }
    }
    
    func fetchAssetsMetadata(assets: PHFetchResultCollection) {
        assets.forEach { asset in
            if let resource = PHAssetResource.assetResources(for: asset).first {
                let metadata = PHAssetMetadata(sizeOnDisk: resource.sizeOnDisk, isVideo: resource.type == .video)
                assetResourceCache.insert(metadata, forKey: asset.localIdentifier)
            }
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
    
    func fetchAssetsGroupByDate(fetchResult: PHFetchResult<PHAsset>) -> [AssetSection] {
        let assets = PHFetchResultCollection(fetchResult: fetchResult)
        let groups = Dictionary(grouping: assets) { element in
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
                    return (assetResourceCache.value(forKey: lhs.localIdentifier)?.sizeOnDisk ?? 0) > (assetResourceCache.value(forKey: rhs.localIdentifier)?.sizeOnDisk ?? 0)
                }),
                style: .normalGrid
            )
        }
        return sections
    }
    
    func fetchAssetsMd5() async {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        let assets = PHFetchResultCollection(fetchResult: result)
        let _ = await withTaskGroup(of: (String, [UInt8])?.self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask(priority: .high) {
                    return try? await self.fetchMd5(index: index, asset: asset)
                }
            }
            for await result in group {
                if let result = result {
                    self.assetMd5[result.0] = result.1
                }
            }
        }
    }
    
    func fetchScreenshots() async -> [AssetSection] {
        let options = PHFetchOptions()
        options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: true) ]
        options.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        let assets = PHFetchResultCollection(fetchResult: fetchResult)
        var hashTable = [[UInt8]: [PHAsset]]()
        
        assets.forEach { asset in
            if let md5 = assetMd5[asset.localIdentifier] {
                if let _ = hashTable[md5] {
                    hashTable[md5]?.append(asset)
                } else {
                    hashTable[md5] = [asset]
                }
            }
        }
        var sections = [AssetSection]()
        sections.append(contentsOf: hashTable.filter { $0.value.count > 1 }.map { item in
            AssetSection(title: "\(item.value.count) duplicates", assets: item.value, style: .horizontalRect)
        })
        let singleAssets = hashTable.filter { $0.value.count == 1 }.flatMap(\.value)
        sections.append(AssetSection(title: "Other", assets: singleAssets, style: .normalGrid))
        return sections
    }
    
    func fetchDuplicatedPhotos() async -> [AssetSection] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let allPhotos = PHAsset.fetchAssets(with: fetchOptions)
        let assets = PHFetchResultCollection(fetchResult: allPhotos)
        
        var hashTable = [[UInt8]: [PHAsset]]()
        
        assets.forEach { asset in
            if let md5 = assetMd5[asset.localIdentifier] {
                if let _ = hashTable[md5] {
                    hashTable[md5]?.append(asset)
                } else {
                    hashTable[md5] = [asset]
                }
            }
        }
        
        return hashTable.filter { $0.value.count > 1 }.map { (key, assets) in
            return AssetSection(title: "\(assets.count) duplicates", assets: assets, style: .horizontalSquare)
        }
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
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
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
    
    func fetchMd5(index: Int, asset: PHAsset) async throws -> (String, [UInt8]) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        print("TUNG", "FETCH", index)
        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(for: asset, targetSize: .init(width: 24, height: 24), contentMode: .aspectFit, options: options) { image, _ in
                print("TUNG", "FETCHED", index)
                if let imageData = image?.pngData() {
                    var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
                    _ = imageData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                        CC_MD5(bytes.baseAddress, CC_LONG(imageData.count), &digest)
                    }
                    continuation.resume(returning: (asset.localIdentifier, digest))
                } else {
                    continuation.resume(throwing: NSError(domain: "ImageManagerError", code: 0, userInfo: nil))
                }
            }
        }
    }
        
}
