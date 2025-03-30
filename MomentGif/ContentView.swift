//
//  ContentView.swift
//  MomentGif
//
//  Created by cxhello on 2024/12/29.
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var photoViewModel = PhotoViewModel()
    @State private var showingPermissionAlert = false
    @State private var selectedAsset: PHAsset?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad 布局
                NavigationSplitView {
                    photoListView
                        .navigationDestination(for: PHAsset.self) { asset in
                            LivePhotoDetailView(asset: asset)
                        }
                        .alert("permission_needed".localized, isPresented: $showingPermissionAlert) {
                            Button("settings".localized, role: .none) {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }
                            Button("cancel".localized, role: .cancel) {}
                        } message: {
                            Text("permission_description".localized)
                        }
                } detail: {
                    detailView
                }
            } else {
                // iPhone 布局
                NavigationStack {
                    photoListView
                        .navigationDestination(for: PHAsset.self) { asset in
                            LivePhotoDetailView(asset: asset)
                        }
                        .alert("permission_needed".localized, isPresented: $showingPermissionAlert) {
                            Button("settings".localized, role: .none) {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }
                            Button("cancel".localized, role: .cancel) {}
                        } message: {
                            Text("permission_description".localized)
                        }
                }
            }
        }
        .task {
            await photoViewModel.requestAuthorization()
        }
    }
    
    private var photoListView: some View {
        VStack {
            if photoViewModel.isAuthorized {
                LivePhotoGridView(photos: photoViewModel.livePhotos, selectedAsset: $selectedAsset)
            } else {
                RequestPermissionView(showingAlert: $showingPermissionAlert)
            }
        }
        .navigationTitle("live_photos_title".localized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: photoViewModel.refreshPhotos) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let asset = selectedAsset {
            LivePhotoDetailView(asset: asset)
        } else {
            ContentUnavailableView(
                "select_photo_prompt".localized,
                systemImage: "photo.on.rectangle"
            )
        }
    }
}

// 请求权限视图
struct RequestPermissionView: View {
    @Binding var showingAlert: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("permission_needed".localized)
                .font(.title2)
            Text("permission_description".localized)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button("authorize_access".localized) {
                showingAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// 照片网格视图
struct LivePhotoGridView: View {
    let photos: [PHAsset]
    @Binding var selectedAsset: PHAsset?
    
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(photos, id: \.localIdentifier) { asset in
                    NavigationLink(value: asset) {
                        PhotoGridItem(asset: asset)
                    }
                }
            }
            .padding(1)
        }
        .background(Color.black.opacity(0.1))
    }
}

// 网格项组件
struct PhotoGridItem: View {
    let asset: PHAsset
    
    var body: some View {
        LivePhotoThumbnailView(asset: asset)
            .aspectRatio(1, contentMode: .fill)
            .clipped()
    }
}

// 缩略图视图
struct LivePhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView())
                    }
                }
                .clipped()
                
                // Live Photo 标记
                LivePhotoIndicator()
            }
        }
        .task {
            image = await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .exact
            options.isSynchronous = false
            
            let targetSize = CGSize(width: 300, height: 300)
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// Live Photo 指示器
struct LivePhotoIndicator: View {
    var body: some View {
        Image(systemName: "livephoto")
            .font(.caption)
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .padding(4)
    }
}

// ViewModel
class PhotoViewModel: ObservableObject {
    @Published var livePhotos: [PHAsset] = []
    @Published var isAuthorized = false
    
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            isAuthorized = status == .authorized
            if isAuthorized {
                Task {
                    await fetchLivePhotos()
                }
            }
        }
    }
    
    func refreshPhotos() {
        Task {
            await fetchLivePhotos()
        }
    }
    
    @MainActor
    private func fetchLivePhotos() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoLive.rawValue)
        
        let result = PHAsset.fetchAssets(with: options)
        var photos: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            photos.append(asset)
        }
        
        self.livePhotos = photos
    }
}

#Preview {
    ContentView()
}
