import SwiftUI
import PhotosUI

struct LivePhotoView: UIViewRepresentable {
    let asset: PHAsset
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        return view
    }
    
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        Task {
            let livePhoto = try? await loadLivePhoto(for: asset)
            await MainActor.run {
                uiView.livePhoto = livePhoto
                uiView.startPlayback(with: .full)
            }
        }
    }
    
    private func loadLivePhoto(for asset: PHAsset) async throws -> PHLivePhoto {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { livePhoto, info in
                if let livePhoto = livePhoto {
                    continuation.resume(returning: livePhoto)
                } else {
                    continuation.resume(throwing: NSError(domain: "LivePhotoError", code: -1))
                }
            }
        }
    }
} 