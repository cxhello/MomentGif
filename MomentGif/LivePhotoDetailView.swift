import SwiftUI
import Photos

struct LivePhotoDetailView: View {
    let asset: PHAsset
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var conversionOptions = GIFConverter.ConversionOptions()
    @State private var isConverting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var conversionProgress: Double = 0
    
    private let converter = GIFConverter()
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad 布局
                HStack(spacing: 0) {
                    // 左侧预览
                    previewSection
                        .frame(maxWidth: .infinity)
                    
                    // 右侧设置
                    settingsSection
                        .frame(width: 320)
                        .background(Color(.systemBackground))
                }
            } else {
                // iPhone 布局
                ScrollView {
                    VStack(spacing: 20) {
                        previewSection
                        settingsSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("convert_gif_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("alert_title".localized, isPresented: $showingAlert) {
            HStack {
                Button("ok".localized, role: .cancel) {}
                Button("view_in_photos".localized) {
                    openPhotosApp()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var previewSection: some View {
        VStack {
            LivePhotoView(asset: asset)
                .aspectRatio(CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight), contentMode: .fit)
                .frame(maxHeight: 300)
            
            if isConverting {
                ProgressView(value: conversionProgress) {
                    Text("converting_progress".localizedFormat(Int(conversionProgress * 100)))
                }
                .progressViewStyle(.linear)
                .padding()
            }
        }
    }
    
    private var settingsSection: some View {
        VStack(spacing: 20) {
            ConversionOptionsView(options: $conversionOptions)
            
            Button(action: convertToGIF) {
                if isConverting {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("convert_button".localized)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConverting)
        }
        .padding()
    }
    
    private func convertToGIF() {
        isConverting = true
        conversionProgress = 0
        
        Task {
            do {
                let gifURL = try await converter.convertLivePhotoToGIF(
                    asset: asset,
                    options: conversionOptions,
                    progressHandler: { progress in
                        Task { @MainActor in
                            conversionProgress = progress
                        }
                    }
                )
                try await converter.saveGIFToPhotos(at: gifURL)
                
                await MainActor.run {
                    alertMessage = "save_success".localized
                    showingAlert = true
                    isConverting = false
                    conversionProgress = 0
                }
            } catch {
                await MainActor.run {
                    alertMessage = String(format: "%@：%@", "conversion_failed".localized, error.localizedDescription)
                    showingAlert = true
                    isConverting = false
                    conversionProgress = 0
                }
            }
        }
    }
    
    private func openPhotosApp() {
        if let photosURL = URL(string: "photos-redirect://") {
            UIApplication.shared.open(photosURL, options: [:], completionHandler: nil)
        }
    }
}

struct ConversionOptionsView: View {
    @Binding var options: GIFConverter.ConversionOptions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("conversion_options".localized)
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("frame_rate".localizedFormat(options.frameRate))
                Slider(
                    value: .init(
                        get: { Double(options.frameRate) },
                        set: { options.frameRate = Int($0) }
                    ),
                    in: 5...30,
                    step: 1
                )
            }
            
            VStack(alignment: .leading) {
                Text("quality".localizedFormat(Int(options.quality * 100)))
                Slider(
                    value: $options.quality,
                    in: 0.1...1
                )
            }
            
            VStack(alignment: .leading) {
                Text("scale".localizedFormat(options.scale))
                Slider(
                    value: $options.scale,
                    in: 0.5...2,
                    step: 0.1
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}