import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager.shared
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var searchText = ""
    @State private var showAboutSheet = false
    @State private var showStatistics = false
    @State private var showSettings = false
    @State private var showOCRSheet = false
    @State private var showClearAllConfirmation = false
    @Environment(\.colorScheme) private var colorScheme
    
    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.clipboardItems
        
        // Kategori filtrelemesi
        if clipboardManager.selectedCategory != .all {
            if clipboardManager.selectedCategory == .pinned {
                items = items.filter { $0.isPinned }
            } else if clipboardManager.selectedCategory == .favorite {
                items = items.filter { $0.isFavorite }
            } else {
                items = items.filter { $0.category == clipboardManager.selectedCategory }
            }
        }
        
        // Arama filtrelemesi
        if !searchText.isEmpty {
            items = items.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            let pinnedItems = items.filter { $0.isPinned }
            let unpinnedItems = items.filter { !$0.isPinned }
            items = pinnedItems + unpinnedItems
        }
        
        return items
    }
    
    var body: some View {
        Group {
            if !onboardingManager.isOnboardingCompleted {
                OnboardingView(onboardingManager: onboardingManager)
            } else {
                mainContentView
            }
        }
        .onAppear {
            setupNotificationObserver()
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutView(showAboutSheet: $showAboutSheet)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(showSettings: $showSettings)
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(showStatistics: $showStatistics)
        }
        .sheet(isPresented: $showOCRSheet) {
            ImageOCRView(isPresented: $showOCRSheet)
        }
    }
    
    private var mainContentView: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    if !clipboardManager.clipboardItems.isEmpty {
                        HeaderSectionView(
                            clipboardManager: clipboardManager,
                            searchText: $searchText
                        )
                    }
                    
                    ContentSectionView(
                        clipboardManager: clipboardManager,
                        filteredItems: filteredItems,
                        searchText: searchText,
                        showToastMessage: showToastMessage,
                        onDeleteItem: deleteItem,
                        onTogglePin: togglePin
                    )
                    
                    if showToast {
                        ToastView(message: toastMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .offset(y: 10)
                    }
                }
            }
            .navigationTitle("Pano Geçmişi")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !clipboardManager.clipboardItems.isEmpty {
                        Button(action: {
                            showClearAllConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    
                    Button(action: { 
                        HapticManager.trigger(.light)
                        showStatistics = true 
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Button(action: { 
                        HapticManager.trigger(.light)
                        showSettings = true 
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Menu {
                        Button(action: {
                            UserDefaults.standard.removeObject(forKey: "isOnboardingCompleted")
                            onboardingManager.isOnboardingCompleted = false
                        }) {
                            Label("Kurulum Sihirbazı", systemImage: "wand.and.stars")
                        }
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("Klavye Ayarları", systemImage: "keyboard")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showOCRSheet = true
                        }) {
                            Label("Görselden Metin", systemImage: "text.viewfinder")
                        }
                        
                        Button(action: {
                            showAboutSheet = true
                        }) {
                            Label("Hakkında", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .confirmationDialog(
                "Tüm öğeleri silmek istediğinizden emin misiniz?",
                isPresented: $showClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Tümünü Sil", role: .destructive) {
                    withAnimation(.spring()) {
                        clearAllItems()
                        searchText = ""
                    }
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("\(clipboardManager.clipboardItems.count) öğe silinecek. Bu işlem geri alınamaz.")
            }
        }
    }
}

// MARK: - ContentView Helper Functions
extension ContentView {
    
    func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .clipboardManagerDataChanged,
            object: nil,
            queue: .main
        ) { _ in
            clipboardManager.loadItems()
        }
    }
    
    func showToastMessage(_ message: String) {
        withAnimation {
            self.toastMessage = message
            self.showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showToast = false
            }
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showToastMessage("Öğe silindi")
    }
    
    func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showToastMessage(item.isPinned ? "Sabitleme kaldırıldı" : "Sabitlendi")
    }
    
    func clearAllItems() {
        clipboardManager.clearAllItems()
    }
}

// MARK: - Image OCR View (inline)
import PhotosUI

struct ImageOCRView: View {
    @Binding var isPresented: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var capturedImage: UIImage?
    @State private var showCropView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label("Görsel Seç", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Kamera ile Çek", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                if isProcessing { ProgressView("İşleniyor...") }
                if let errorMessage { Text(errorMessage).foregroundColor(.red).font(.footnote) }
                Spacer()
            }
            .padding()
            .navigationTitle("Görselden Metin")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { isPresented = false }
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                InlineCustomCameraView { image in
                    capturedImage = image
                    isShowingCamera = false
                    // Hemen aç
                    showCropView = true
                }
            }
            .fullScreenCover(isPresented: $showCropView) {
                if let image = capturedImage {
                    ImageCropOCRView(
                        image: image,
                        onComplete: {
                            isPresented = false
                        },
                        onCancel: {
                            capturedImage = nil
                        }
                    )
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task { await handleSelection(item: newItem) }
            }
        }
    }
    
    @State private var isShowingCamera = false
    
    @MainActor
    private func handleSelection(item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Görsel okunamadı"
                return
            }
            capturedImage = image
            showCropView = true
        } catch {
            errorMessage = "Görsel yüklenemedi: \(error.localizedDescription)"
        }
    }
    
    
}


#Preview {
    ContentView()
}

// MARK: - Inline Custom Camera (SwiftUI + AVFoundation)
final class InlineCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "inline.camera.queue")
    private let photoOutput = AVCapturePhotoOutput()
    @Published var torchOn = false
    @Published var authorizationDenied = false
    private var input: AVCaptureDeviceInput?
    private var onPhoto: ((Data) -> Void)?
    private var configured = false
    
    override init() {
        super.init()
    }
    
    private func configureIfNeeded(position: AVCaptureDevice.Position = .back) {
        guard !configured else { log("configureIfNeeded: already configured"); return }
        log("configureIfNeeded: begin (position=\(position == .back ? "back" : "front"))")
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            log("configureIfNeeded: got device=\(device.localizedName)")
            if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input); self.input = input
                log("configureIfNeeded: input added")
            } else {
                log("configureIfNeeded: failed to create/add input")
            }
        } else {
            log("configureIfNeeded: no camera device")
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            if #available(iOS 16.0, *) {
                photoOutput.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
            log("configureIfNeeded: photoOutput added")
        } else {
            log("configureIfNeeded: cannot add photoOutput")
        }
        session.commitConfiguration()
        configured = true
        log("configureIfNeeded: commit")
    }
    
    func start() {
        log("start: invoked")
        sessionQueue.async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            self.log("start: auth status = \(status.rawValue)")
            switch status {
            case .authorized:
                self.configureIfNeeded()
                if !self.session.isRunning { self.session.startRunning(); self.log("start: session started") } else { self.log("start: session already running") }
            case .notDetermined:
                self.log("start: requesting access")
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.sessionQueue.async {
                        self.log("start: requestAccess granted=\(granted)")
                        if granted {
                            self.configureIfNeeded()
                            if !self.session.isRunning { self.session.startRunning(); self.log("start: session started after grant") }
                        } else {
                            DispatchQueue.main.async { self.authorizationDenied = true }
                        }
                    }
                }
            default:
                self.log("start: authorization denied/restricted")
                DispatchQueue.main.async { self.authorizationDenied = true }
            }
        }
    }
    
    func stop() { sessionQueue.async { if self.session.isRunning { self.session.stopRunning(); self.log("stop: session stopped") } else { self.log("stop: session not running") } } }
    func toggleTorch() {
        guard let device = input?.device else { log("toggleTorch: no device"); return }
        guard device.hasTorch else { log("toggleTorch: device has no torch"); return }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            torchOn = device.torchMode == .on
            device.unlockForConfiguration()
            log("toggleTorch: torch=\(torchOn)")
        } catch {
            log("toggleTorch: error=\(error.localizedDescription)")
        }
    }
    func switchCamera() {
        session.beginConfiguration()
        let oldPos = input?.device.position ?? .back
        if let current = input { session.removeInput(current); log("switchCamera: removed input (was=\(oldPos == .back ? "back" : "front"))") }
        let newPos: AVCaptureDevice.Position = oldPos == .back ? .front : .back
        if let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPos), let newInput = try? AVCaptureDeviceInput(device: dev), session.canAddInput(newInput) {
            session.addInput(newInput); input = newInput; log("switchCamera: added input (now=\(newPos == .back ? "back" : "front"))")
        } else {
            log("switchCamera: failed to add input for position=\(newPos == .back ? "back" : "front")")
        }
        session.commitConfiguration()
    }
    func capture(_ onPhoto: @escaping (Data) -> Void) {
        self.onPhoto = onPhoto
        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }
        if let dev = input?.device, dev.hasFlash { settings.flashMode = torchOn ? .on : .off }
        log("capture: triggered (flash=\(torchOn))")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { log("photoOutput error=\(error.localizedDescription)"); return }
        guard let data = photo.fileDataRepresentation() else { log("photoOutput: no data"); return }
        log("photoOutput: got data size=\(data.count) bytes")
        onPhoto?(data); onPhoto = nil
    }
    private func log(_ message: String) { print("[Camera] \(message)") }
}

final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { return layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct InlineCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        let layer = view.previewLayer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        if let conn = layer.connection {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(0) {
                    conn.videoRotationAngle = 0
                }
            } else {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
            }
        }
        return view
    }
    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
        if let conn = uiView.previewLayer.connection {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(0) {
                    conn.videoRotationAngle = 0
                }
            } else {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
            }
        }
    }
}

struct InlineCustomCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = InlineCameraController()
    let onCapture: (UIImage) -> Void
    var body: some View {
        ZStack {
            InlineCameraPreview(session: controller.session).ignoresSafeArea()
            VStack {
                if controller.authorizationDenied {
                    Text("Kamera izni gerekli. Ayarlar > Gizlilik > Kamera üzerinden izin verin.")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 20)
                }
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").padding(10).background(.ultraThinMaterial, in: Circle()) }
                    Spacer()
                    Button { controller.toggleTorch() } label: { Image(systemName: controller.torchOn ? "bolt.fill" : "bolt.slash").padding(10).background(.ultraThinMaterial, in: Circle()) }
                }.padding([.top,.horizontal], 16)
                Spacer()
                HStack {
                    Button { controller.switchCamera() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera").padding(14).background(.ultraThinMaterial, in: Circle()) }
                    Spacer()
                    Button { 
                        controller.capture { data in 
                            // Background'da decode et
                            DispatchQueue.global(qos: .userInitiated).async {
                                if let img = UIImage(data: data) { 
                                    DispatchQueue.main.async { 
                                        onCapture(img)
                                        dismiss() 
                                    } 
                                } 
                            }
                        } 
                    } label: {
                        ZStack { Circle().fill(Color.white.opacity(0.15)).frame(width: 78, height: 78); Circle().fill(Color.white).frame(width: 64, height: 64) }
                    }
                    Spacer()
                    Color.clear.frame(width: 48, height: 48)
                }.padding(.horizontal, 40).padding(.bottom, 28)
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }
}
import SwiftUI
import Vision

/// Fotoğraf önizleme ve OCR için alan seçimi
struct ImageCropOCRView: View {
    let image: UIImage
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var cropRect: CGRect = .zero
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var imageFrame: CGRect = .zero
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                .onTapGesture { /* Toolbar gesture'dan korun */ }
                
                GeometryReader { geometry in
                    let displaySize = calculateImageDisplaySize(containerSize: geometry.size)
                    let displayOrigin = CGPoint(
                        x: (geometry.size.width - displaySize.width) / 2,
                        y: (geometry.size.height - displaySize.height) / 2
                    )
                    
                    ZStack {
                        // Orijinal fotoğraf
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .allowsHitTesting(false)
                            .onAppear {
                                imageFrame = CGRect(origin: displayOrigin, size: displaySize)
                            }
                        
                        // Karartma overlay (seçilen alan hariç)
                        if cropRect != .zero {
                            DimmingOverlay(cropRect: cropRect, geometry: geometry)
                                .allowsHitTesting(false)
                        }
                        
                        // Crop rectangle
                        if cropRect != .zero {
                            CropRectangle(rect: cropRect)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(value: value, imageFrame: imageFrame)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
                
                // İşlem durumu
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Metin çıkarılıyor...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                }
                
                // Hata mesajı
                if let errorMessage = errorMessage {
                    VStack {
                        Spacer()
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Alan Seç")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(cropRect == .zero ? "Parmağınızla çizin" : "Seçilen alan işlenecek")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if cropRect != .zero {
                            Button(action: resetSelection) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: processOCR) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(cropRect == .zero ? .gray : .green)
                                .font(.title3)
                        }
                        .disabled(cropRect == .zero || isProcessing)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
    }
    
    // MARK: - Drag Handling
    
    private func handleDrag(value: DragGesture.Value, imageFrame: CGRect) {
        if !isDragging {
            isDragging = true
            dragStart = value.location
            cropRect = CGRect(origin: dragStart, size: .zero)
        }
        
        let currentPoint = value.location
        
        let x = min(dragStart.x, currentPoint.x)
        let y = min(dragStart.y, currentPoint.y)
        let width = abs(currentPoint.x - dragStart.x)
        let height = abs(currentPoint.y - dragStart.y)
        
        // Image frame sınırları içinde tut
        let constrainedX = max(imageFrame.minX, min(x, imageFrame.maxX))
        let constrainedY = max(imageFrame.minY, min(y, imageFrame.maxY))
        let constrainedWidth = min(width, imageFrame.maxX - constrainedX)
        let constrainedHeight = min(height, imageFrame.maxY - constrainedY)
        
        cropRect = CGRect(
            x: constrainedX,
            y: constrainedY,
            width: constrainedWidth,
            height: constrainedHeight
        )
    }
    
    private func calculateImageDisplaySize(containerSize: CGSize) -> CGSize {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect {
            // Image daha geniş - width'e sığdır
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image daha uzun - height'a sığdır
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
    
    private func resetSelection() {
        withAnimation(.easeInOut(duration: 0.3)) {
            cropRect = .zero
        }
    }
    
    // MARK: - OCR Processing
    
    private func processOCR() {
        guard cropRect != .zero else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // Crop edilen alanı al
                let croppedImage = cropImage(image, to: cropRect)
                
                // OCR işle
                guard let imageData = croppedImage.jpegData(compressionQuality: 0.9) else {
                    await MainActor.run {
                        errorMessage = "Görsel işlenemedi"
                        isProcessing = false
                    }
                    return
                }
                
                let ocrText = try await MediaProcessor().extractTextFromImage(imageData)
                
                await MainActor.run {
                    guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        errorMessage = "Seçilen alanda metin bulunamadı"
                        isProcessing = false
                        return
                    }
                    
                    ClipboardManager.shared.addItem(ocrText)
                    ClipboardManager.shared.saveItems()
                    HapticManager.trigger(.success)
                    
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "OCR başarısız: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private func cropImage(_ image: UIImage, to viewRect: CGRect) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        guard imageFrame != .zero else { return image }
        
        // Image'ın gerçek pixel boyutları
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // viewRect'i imageFrame'e göre normalize et
        let normalizedX = (viewRect.origin.x - imageFrame.origin.x) / imageFrame.width
        let normalizedY = (viewRect.origin.y - imageFrame.origin.y) / imageFrame.height
        let normalizedWidth = viewRect.width / imageFrame.width
        let normalizedHeight = viewRect.height / imageFrame.height
        
        // Normalize edilmiş koordinatları pixel koordinatlarına çevir
        let cropX = normalizedX * imageWidth
        let cropY = normalizedY * imageHeight
        let cropWidth = normalizedWidth * imageWidth
        let cropHeight = normalizedHeight * imageHeight
        
        let cropRect = CGRect(
            x: max(0, cropX),
            y: max(0, cropY),
            width: min(cropWidth, imageWidth - cropX),
            height: min(cropHeight, imageHeight - cropY)
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Supporting Views

struct CropRectangle: View {
    let rect: CGRect
    
    var body: some View {
        Rectangle()
            .stroke(Color.green, lineWidth: 3)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .overlay(
                // Corner handles
                Group {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .position(x: rect.minX, y: rect.minY)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .position(x: rect.maxX, y: rect.minY)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .position(x: rect.minX, y: rect.maxY)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .position(x: rect.maxX, y: rect.maxY)
                }
            )
            .overlay(
                // Boyut bilgisi
                VStack {
                    Text("\(Int(rect.width)) × \(Int(rect.height))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(4)
                }
                .position(x: rect.midX, y: rect.minY - 20)
            )
    }
}

struct DimmingOverlay: View {
    let cropRect: CGRect
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Top
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(width: geometry.size.width, height: cropRect.minY)
                .position(x: geometry.size.width / 2, y: cropRect.minY / 2)
            
            // Bottom
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(width: geometry.size.width, height: geometry.size.height - cropRect.maxY)
                .position(x: geometry.size.width / 2, y: cropRect.maxY + (geometry.size.height - cropRect.maxY) / 2)
            
            // Left
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(width: cropRect.minX, height: cropRect.height)
                .position(x: cropRect.minX / 2, y: cropRect.midY)
            
            // Right
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(width: geometry.size.width - cropRect.maxX, height: cropRect.height)
                .position(x: cropRect.maxX + (geometry.size.width - cropRect.maxX) / 2, y: cropRect.midY)
        }
    }
}
