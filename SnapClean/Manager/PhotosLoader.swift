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
    @Published var allAssets: [AssetSection] = []
    @Published var largeAssets: [AssetSection] = []
    @Published var screenshots: [AssetSection] = []
    @Published var duplicatedPhotos: [AssetSection] = []
    @Published var similarPhotos: [AssetSection] = []
    
    var assetMetadataCache = [String: PHAssetMetadata]()
    var assetMd5: [String: [UInt8]] = [:]
    var lastUpdatedTime: Date?
    let minLargeFileSize: Float = 5 * 1024 * 1024
    
    @Published var allAssetsSize: Float = 0
    @Published var largeAssetsSize: Float = 0
    @Published var screenshotsSize: Float = 0
    @Published var duplicatedPhotosSize: Float = 0
    @Published var similarPhotosSize: Float = 0
    
    init() {
        assetMetadataCache = loadStorageMetadata()
        assetMd5 = loadStorageMd5()
        lastUpdatedTime = UserDefaults.standard.object(forKey: "last_updated_time") as? Date
    }
    
    func reloadData() async {
        fetchAssetsMetadata()
        saveMetadataToDisk(data: assetMetadataCache)
        
        Task { @MainActor in
            largeAssets = fetchLargeAssets()
            allAssetsSize = getTotalSize(sections: allAssets)
            largeAssetsSize = getTotalSize(sections: largeAssets)
            similarPhotosSize = getTotalSize(sections: similarPhotos)
        }
        
        await fetchAssetsMd5()
        saveMd5ToDisk(data: assetMd5)
        UserDefaults.standard.setValue(Date(), forKey: "last_updated_time")
        
        Task { @MainActor in
            // Fetch new data
            screenshots = await fetchScreenshots()
            screenshotsSize = getTotalSize(sections: screenshots)
            
            duplicatedPhotos = await fetchDuplicatedPhotos()
            duplicatedPhotosSize = getTotalSize(sections: duplicatedPhotos)
        }
    }
    
    func getTotalSize(sections: [AssetSection]) -> Float {
        return sections.flatMap(\.assets).reduce(0, { $0 + (assetMetadataCache[$1.localIdentifier]?.sizeOnDisk ?? 0) })
    }
    
    func fetchAllAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [.init(key: "creationDate", ascending: false)]
        
        let result = PHAsset.fetchAssets(with: options)
        allAssets = fetchAllAssetsGroupByDate(fetchResult: result)
        similarPhotos = fetchSimilarAssets()
    }
    
    func fetchLargeAssets() -> [AssetSection] {
        return allAssets.compactMap { section -> AssetSection? in
            let assets = section.assets.filter {
                return (assetMetadataCache[$0.localIdentifier]?.sizeOnDisk ?? 0) > minLargeFileSize
            }
            if assets.isEmpty {
                return nil
            } else {
                return .init(title: section.title, assets: assets.sorted(by: { lhs, rhs in
                    return (assetMetadataCache[lhs.localIdentifier]?.sizeOnDisk ?? 0) > (assetMetadataCache[rhs.localIdentifier]?.sizeOnDisk ?? 0)
                }), style: section.style)
            }
        }
    }
    
    func fetchAssetsMetadata() {
        let options = PHFetchOptions()
        options.sortDescriptors = [.init(key: "creationDate", ascending: false)]
        if let lastUpdatedTime = lastUpdatedTime as? NSDate {
            options.predicate = NSPredicate(format: "creationDate > %@ OR modificationDate > %@", lastUpdatedTime, lastUpdatedTime)
        }
        let result = PHAsset.fetchAssets(with: options)
        result.enumerateObjects { asset, index, stop in
            if let resource = PHAssetResource.assetResources(for: asset).first {
                let metadata = PHAssetMetadata(sizeOnDisk: resource.sizeOnDisk, isVideo: resource.type == .video)
                self.assetMetadataCache[asset.localIdentifier] = metadata
            }
        }
    }
    
    func fetchAllAssetsGroupByDate(fetchResult: PHFetchResult<PHAsset>) -> [AssetSection] {
        var sections = [AssetSection]()
        var currentDate: Date?
        var currentSection: AssetSection?
        fetchResult.enumerateObjects { asset, index, stop in
            let date = Calendar.current.startOfDay(for: asset.creationDate ?? Date())
            if date != currentDate {
                if let currentSection = currentSection {
                    sections.append(currentSection)
                }
                currentSection = AssetSection(
                    title: date.displayText,
                    assets: [asset],
                    style: .normalGrid
                )
                currentDate = date
            } else {
                currentSection?.assets.append(asset)
            }
        }
        return sections
    }
    
    func fetchAssetsMd5() async {
        let options = PHFetchOptions()
        let lastUpdatedTime = (lastUpdatedTime ?? Date(timeIntervalSince1970: 0)) as NSDate
        options.predicate = NSPredicate(
            format: "mediaType = %d AND (creationDate > %@ OR modificationDate > %@)",
            PHAssetMediaType.image.rawValue, lastUpdatedTime, lastUpdatedTime
        )
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
        let duplicated = hashTable.values.filter { $0.count > 1 }
        return duplicated.map { assets in
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
        options.deliveryMode = .highQualityFormat
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
    
    func fetchSimilarAssets() -> [AssetSection] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets = [AssetSection]()
        var similarAssets = [PHAsset]()
        var previousCreationDate: Date?
        fetchResult.enumerateObjects { asset, index, stop in
            if let previousCreationDate = previousCreationDate, abs(asset.creationDate!.timeIntervalSince(previousCreationDate)) < 1 {
                similarAssets.append(asset)
            } else {
                if similarAssets.count > 1 {
                    assets.append(.init(title: "\(similarAssets.count) similars", assets: similarAssets, style: .horizontalSquare))
                }
                similarAssets = [asset]
            }
            previousCreationDate = asset.creationDate
        }
        return assets
    }
    
}

extension PhotosLoader {
    
    func getDocumentFile(fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentDirectory.appendingPathComponent(fileName)
    }
    
    func saveMetadataToDisk(data: [String: PHAssetMetadata]) {
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(data), let url = getDocumentFile(fileName: "metadata.json") {
            try? jsonData.write(to: url)
        }
    }
    
    func saveMd5ToDisk(data: [String: [UInt8]]) {
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(data), let url = getDocumentFile(fileName: "md5.json") {
            try? jsonData.write(to: url)
        }
    }
    
    func loadStorageMetadata() -> [String: PHAssetMetadata] {
        if let url = getDocumentFile(fileName: "metadata.json"), let jsonData = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let data = try? decoder.decode([String: PHAssetMetadata].self, from: jsonData) {
                return data
            }
        }
        return [:]
    }
    
    func loadStorageMd5() -> [String: [UInt8]] {
        if let url = getDocumentFile(fileName: "md5.json"), let jsonData = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let data = try? decoder.decode([String: [UInt8]].self, from: jsonData) {
                return data
            }
        }
        return [:]
    }
    
}
