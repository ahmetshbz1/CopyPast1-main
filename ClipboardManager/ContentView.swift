import SwiftUI
import UIKit
import AVFoundation

// Lightweight performance logger
fileprivate enum Perf {
    private static var marks: [String: TimeInterval] = [:]
    private static func now() -> TimeInterval { Date().timeIntervalSince1970 }
    static func mark(_ key: String) { marks[key] = now(); print("[PERF] mark \(key)") }
    static func since(_ key: String, _ label: String) {
        guard let t = marks[key] else { print("[PERF] \(label): missing mark \(key)"); return }
        let dt = now() - t
        print("[PERF] \(label): \(String(format: "%.3f", dt))s")
    }
    static func between(_ start: String, _ end: String, _ label: String) {
        guard let s = marks[start], let e = marks[end] else { print("[PERF] \(label): missing marks \(start)/\(end)"); return }
        print("[PERF] \(label): \(String(format: "%.3f", e - s))s")
    }
}

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
.sheet(isPresented: $isShowingCamera, onDismiss: {
                Perf.since("camera.sheet.dismiss.start", "camera: sheet dismiss animation")
                print("[DEBUG] Sheet dismiss edildi, capturedImage: \(capturedImage != nil)")
                if capturedImage != nil {
                    print("[DEBUG] Crop view açılıyor...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        print("[DEBUG] showCropView = true")
                        Perf.mark("crop.toggle.true")
                        showCropView = true
                    }
                }
            }) {
                InlineCustomCameraView { image in
                    print("[DEBUG] Fotoğraf çekildi, boyut: \(image.size)")
                    capturedImage = image
                    isShowingCamera = false
                    print("[DEBUG] Sheet kapatma başlatıldı")
                }
            }
            .fullScreenCover(isPresented: $showCropView) {
                let _ = print("[DEBUG] fullScreenCover tetiklendi, showCropView: \(showCropView)")
                if let image = capturedImage {
                    let _ = print("[DEBUG] ImageCropOCRView oluşturuluyor")
                    ImageCropOCRView(
                        image: image,
                        onComplete: {
                            isPresented = false
                        },
                        onCancel: {
                            capturedImage = nil
                        }
                    )
                    .onAppear { Perf.since("crop.toggle.true", "crop: present delay") }
                    .interactiveDismissDisabled(true)
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
        Perf.mark("gallery.select.start")
        isProcessing = true
        defer { isProcessing = false }
        do {
            let loadStart = Date().timeIntervalSince1970
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Görsel okunamadı"
                return
            }
            // Decode'u background thread'de yap
            let decodeStart = Date().timeIntervalSince1970
            let image = try await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
            let decodeEnd = Date().timeIntervalSince1970
            print("[PERF] gallery: load transferable \(String(format: "%.3f", decodeStart - loadStart))s, decode \(String(format: "%.3f", decodeEnd - decodeStart))s")
            guard let image else {
                errorMessage = "Görsel okunamadı"
                return
            }
            capturedImage = image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Perf.mark("crop.toggle.true")
                showCropView = true
            }
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
                        Perf.mark("camera.capture.tap")
                        controller.capture { data in 
                            Perf.since("camera.capture.tap", "camera: capture→data")
                            // Background'da decode et
                            DispatchQueue.global(qos: .userInitiated).async {
                                let t0 = Date().timeIntervalSince1970
                                let img = UIImage(data: data)
                                let t1 = Date().timeIntervalSince1970
                                print("[PERF] camera: decode time \(String(format: "%.3f", t1 - t0))s (data=\(data.count) bytes)")
                                if let img = img {
                                    DispatchQueue.main.async { 
                                        Perf.mark("camera.sheet.dismiss.start")
                                        onCapture(img)
                                        dismiss() 
                                    } 
                                } else {
                                    DispatchQueue.main.async {
                                        print("[PERF] camera: decode failed")
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
        let _ = print("[DEBUG] ImageCropOCRView body rendered")
        return NavigationView {
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
                        
                        // Touch capture overlay (gesture sorunlarını aşmak için UIKit tabanlı)
                        TouchCaptureView(
                            onStart: { point in
                                print("[DEBUG] drag start at: \(Int(point.x))x\(Int(point.y))")
                                Perf.mark("crop.drag.start")
                                isDragging = true
                                dragStart = point
                                cropRect = CGRect(origin: dragStart, size: .zero)
                            },
                            onChange: { point in
                                updateCropRect(currentPoint: point, imageFrame: imageFrame)
                            },
                            onEnd: {
                                isDragging = false
                                Perf.since("crop.drag.start", "crop: drag duration")
                                print("[DEBUG] drag end rect: \(Int(cropRect.width))x\(Int(cropRect.height))")
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
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
    
    // MARK: - Drag Handling (UIKit touch overlay ile)
    
    private func updateCropRect(currentPoint: CGPoint, imageFrame: CGRect) {
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
        print("[PERF] ocr: start")
        let t0 = Date().timeIntervalSince1970
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
                let t1 = Date().timeIntervalSince1970
                print("[PERF] ocr: duration \(String(format: "%.3f", t1 - t0))s, cropped size=\(Int(croppedImage.size.width))x\(Int(croppedImage.size.height))")
                
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
        print("[DEBUG] cropImage: image=\(Int(image.size.width))x\(Int(image.size.height)) frame=\(Int(imageFrame.origin.x)),\(Int(imageFrame.origin.y)) \(Int(imageFrame.size.width))x\(Int(imageFrame.size.height)) viewRect=\(Int(viewRect.origin.x)),\(Int(viewRect.origin.y)) \(Int(viewRect.size.width))x\(Int(viewRect.size.height))")
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

// UIKit tabanlı touch capture (SwiftUI gesture çakışmalarını bypass)
final class TouchCaptureUIView: UIView {
    var onStart: ((CGPoint) -> Void)?
    var onChange: ((CGPoint) -> Void)?
    var onEnd: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func point(_ touches: Set<UITouch>) -> CGPoint? {
        guard let t = touches.first else { return nil }
        return t.location(in: self)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let p = point(touches) { onStart?(p) }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let p = point(touches) { onChange?(p) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        onEnd?()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onEnd?()
    }
}

struct TouchCaptureView: UIViewRepresentable {
    let onStart: (CGPoint) -> Void
    let onChange: (CGPoint) -> Void
    let onEnd: () -> Void
    
    func makeUIView(context: Context) -> TouchCaptureUIView {
        let v = TouchCaptureUIView()
        v.onStart = onStart
        v.onChange = onChange
        v.onEnd = onEnd
        return v
    }
    func updateUIView(_ uiView: TouchCaptureUIView, context: Context) {}
}

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
