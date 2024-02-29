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

struct AssetMetadata {
    var resource: PHAssetResource?
    
    var sizeOnDisk: Float {
        if let fileSize = resource?.value(forKey: "fileSize") as? Float {
            return fileSize
        }
        return 0
    }
}

class PhotosLoader: ObservableObject {
    var imageCachingManager = PHCachingImageManager()
    let imageManager = PHImageManager.default()
    var allAssets: PHFetchResultCollection?
    var metadata: [String: AssetMetadata] = [:]
    var largeAssets: [AssetSection] = []
    var screenshots: [AssetSection] = []
    var duplicatedPhotos: [AssetSection] = []
    let cache = Cache<String, AssetMetadata>()
    
    init() {}
    
    func load() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [.init(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        allAssets = PHFetchResultCollection(fetchResult: result)
        
        if let allAssets {
            metadata = await fetchAssetsMetadata(assets: allAssets)
            largeAssets = fetchAssetsGroupByDate(fetchResult: result)
            screenshots = await fetchScreenshots()
//            duplicatedPhotos = await fetchDuplicatedPhotos()
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
        return (asset.localIdentifier, .init(resource: resource))
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
                    return (metadata[lhs.localIdentifier]?.sizeOnDisk ?? 0) > (metadata[rhs.localIdentifier]?.sizeOnDisk ?? 0)
                }),
                style: .normalGrid
            )
        }
        return sections
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
        let hashTable = await withTaskGroup(of: (asset: PHAsset, md5: [UInt8])?.self, returning: [[UInt8]: [PHAsset]].self) { taskGroup in
            for asset in assets {
                taskGroup.addTask { await self.fetchMd5(asset: asset) }
            }
            
            var hashTable = [[UInt8]: [PHAsset]]()
            
            for await result in taskGroup {
                if let result = result {
                    if let _ = hashTable[result.md5] {
                        hashTable[result.md5]?.append(result.asset)
                    } else {
                        hashTable[result.md5] = [result.asset]
                    }
                }
            }
            return hashTable
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

        let hashTable = await withTaskGroup(of: (asset: PHAsset, md5: [UInt8])?.self, returning: [[UInt8]: [PHAsset]].self) { taskGroup in
            for asset in assets {
                taskGroup.addTask { await self.fetchMd5(asset: asset) }
            }
            
            var hashTable = [[UInt8]: [PHAsset]]()
            
            for await result in taskGroup {
                if let result = result {
                    if let _ = hashTable[result.md5] {
                        hashTable[result.md5]?.append(result.asset)
                    } else {
                        hashTable[result.md5] = [result.asset]
                    }
                }
            }
            return hashTable.filter { $0.value.count > 1 }
        }
        
        return hashTable.map { (key, assets) in
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
    
    func fetchMd5(asset: PHAsset) async -> (PHAsset, [UInt8])? {
        return try? await withCheckedThrowingContinuation({
            (continuation: CheckedContinuation<(PHAsset, [UInt8])?, Error>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            self.imageManager.requestImageDataAndOrientation(for: asset, options: options, resultHandler: {
                imageData, _, _, _ in
                if imageData != nil {
                    let digestLength = Int(CC_MD5_DIGEST_LENGTH)
                    var md5Buffer = [UInt8](repeating: 0, count: digestLength)
                    
                    let _ = imageData!.withUnsafeBytes { (body: UnsafePointer<UInt8>) in
                        CC_MD5(body, CC_LONG(imageData!.count), &md5Buffer)
                    }
                    continuation.resume(returning: (asset, md5Buffer))
                } else {
                    continuation.resume(returning: nil)
                }
            })
        })
    }
}
