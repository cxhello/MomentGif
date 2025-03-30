import Photos
import ImageIO
import UniformTypeIdentifiers
import UIKit

actor GIFConverter {
    enum ConversionError: LocalizedError {
        case failedToGetVideoResource
        case failedToCreateDestination
        case conversionFailed
        case failedToSaveToPhotos
        
        var errorDescription: String? {
            switch self {
            case .failedToGetVideoResource:
                return "error.failed_to_get_video".localized
            case .failedToCreateDestination:
                return "error.failed_to_create_destination".localized
            case .conversionFailed:
                return "error.conversion_failed".localized
            case .failedToSaveToPhotos:
                return "error.failed_to_save".localized
            }
        }
    }
    
    struct ConversionOptions {
        var frameRate: Int = 10
        var loopCount: Int = 0  // 0 means infinite
        var quality: Float = 0.7
        var scale: CGFloat = 1.0
    }
    
    func convertLivePhotoToGIF(
        asset: PHAsset,
        options: ConversionOptions = ConversionOptions(),
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        // 创建临时文件URL
        let fileName = "LivePhoto-\(UUID().uuidString).gif"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // 获取Live Photo的视频资源
        let videoResource = try await getLivePhotoVideoResource(for: asset)
        let avAsset = try await loadAVAsset(from: videoResource)
        
        // 计算总帧数
        let duration = try await avAsset.load(.duration)
        let frameCount = Int(duration.seconds * Double(options.frameRate))
        
        // 创建GIF文件
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw ConversionError.failedToCreateDestination
        }
        
        // 设置GIF属性
        let gifProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: options.loopCount
            ]
        ] as CFDictionary
        
        CGImageDestinationSetProperties(destination, gifProperties)
        
        // 提取帧并写入GIF，添加进度回调
        try await extractFramesAndCreateGIF(
            from: avAsset,
            to: destination,
            options: options,
            progressHandler: progressHandler
        )
        
        return fileURL
    }
    
    private func getLivePhotoVideoResource(for asset: PHAsset) async throws -> PHAssetResource {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
            throw ConversionError.failedToGetVideoResource
        }
        return videoResource
    }
    
    private func loadAVAsset(from resource: PHAssetResource) async throws -> AVAsset {
        let data: Data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            var resourceRequestOptions = PHAssetResourceRequestOptions()
            resourceRequestOptions.isNetworkAccessAllowed = true
            
            var loadedData = Data()
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: resourceRequestOptions,
                dataReceivedHandler: { data in
                    loadedData.append(data)
                },
                completionHandler: { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: loadedData)
                    }
                }
            )
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        try data.write(to: tempURL)
        return AVAsset(url: tempURL)
    }
    
    private func extractFramesAndCreateGIF(
        from avAsset: AVAsset,
        to destination: CGImageDestination,
        options: ConversionOptions,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: 480 * options.scale,
            height: 480 * options.scale
        )
        
        let duration = try await avAsset.load(.duration)
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 1.0 / Double(options.frameRate)
            ]
        ] as CFDictionary
        
        let frameCount = Int(duration.seconds * Double(options.frameRate))
        let frameDuration = duration.seconds / Double(frameCount)
        
        for frameNumber in 0..<frameCount {
            let progress = Double(frameNumber) / Double(frameCount)
            await MainActor.run {
                progressHandler(progress)
            }
            
            let time = CMTime(seconds: Double(frameNumber) * frameDuration, preferredTimescale: 600)
            do {
                let image = try await generator.image(at: time).image
                CGImageDestinationAddImage(destination, image, frameProperties)
            } catch {
                continue
            }
        }
        
        await MainActor.run {
            progressHandler(1.0)
        }
        
        if !CGImageDestinationFinalize(destination) {
            throw ConversionError.conversionFailed
        }
    }
    
    func saveGIFToPhotos(at url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        }
    }
} 