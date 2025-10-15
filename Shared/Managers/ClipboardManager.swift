import Foundation
import SwiftUI
import UIKit

public class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()
    
    @Published public var clipboardItems: [ClipboardItem] = []
    @Published public var selectedCategory: ItemCategory = .all
    public let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
    
    private let monitor = ClipboardMonitor()
    
    private init() {
        loadItems()
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        monitor.delegate = self
        monitor.startMonitoring()
    }
    
    public func addItem(_ text: String) {
        let item = ClipboardItem(text: text)
        
        if let existingIndex = clipboardItems.firstIndex(where: { $0.text == text }) {
            clipboardItems.remove(at: existingIndex)
        }
        
        clipboardItems.insert(item, at: 0)
        
        // Ayarlardan max item sayısını al, yoksa default kullan
        let maxItems = UserDefaults.standard.integer(forKey: "maxClipboardItems")
        let limit = maxItems > 0 ? maxItems : Constants.maxClipboardItems
        
        if clipboardItems.count > limit {
            // Fazla öğeleri sil ama sabitli ve favori olanları koru
            let excess = clipboardItems.count - limit
            let removableItems = clipboardItems
                .enumerated()
                .filter { !$0.element.isPinned && !$0.element.isFavorite }
                .suffix(excess)
            
            for (_, item) in removableItems {
                clipboardItems.removeAll { $0.id == item.id }
            }
        }
        
        NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
    }
    
    // Kullanım istatistikleri
    public func registerUsage(byText text: String) {
        if let index = clipboardItems.firstIndex(where: { $0.text == text }) {
            clipboardItems[index].usageCount += 1
            clipboardItems[index].lastUsedDate = Date()
            saveItems()
        }
    }
    
    public func loadItems() {
        if let data = userDefaults?.data(forKey: Constants.clipboardItemsKey),
           let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            clipboardItems = items
        }
    }
    
    public func saveItems() {
        if let data = try? JSONEncoder().encode(clipboardItems) {
            userDefaults?.set(data, forKey: Constants.clipboardItemsKey)
            userDefaults?.synchronize()
            
            DispatchQueue.main.async {
                self.notifyClipboardChanged()
                self.monitor.postDarwinNotification()
            }
        }
    }
    
    public func updateItem(_ item: ClipboardItem, newText: String) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].text = newText
            saveItems()
        }
    }
    
    public func deleteItem(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems.remove(at: index)
            saveItems()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil, userInfo: ["action": "delete", "itemId": item.id.uuidString])
            }
        }
    }
    
    public func togglePinItem(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].isPinned.toggle()
            saveItems()
            notifyClipboardChanged()
        }
    }
    
    public func toggleFavoriteItem(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].isFavorite.toggle()
            saveItems()
            notifyClipboardChanged()
        }
    }
    
    public func addTag(_ tag: String, to item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            if !clipboardItems[index].tags.contains(tag) {
                clipboardItems[index].tags.append(tag)
                saveItems()
                notifyClipboardChanged()
            }
        }
    }
    
    public func removeTag(_ tag: String, from item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].tags.removeAll { $0 == tag }
            saveItems()
            notifyClipboardChanged()
        }
    }
    
    public func updateNote(_ note: String?, for item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].note = note
            saveItems()
            notifyClipboardChanged()
        }
    }
    
    public func clearAllItems() {
        clipboardItems.removeAll()
        userDefaults?.removeObject(forKey: Constants.clipboardItemsKey)
        notifyClipboardChanged()
    }
    
    private func notifyClipboardChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardManagerDataChanged, object: nil)
            self.loadItems()
            NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
        }
    }
    
}

// MARK: - ClipboardMonitorDelegate
extension ClipboardManager: ClipboardMonitorDelegate {
    func clipboardMonitor(_ monitor: ClipboardMonitor, didDetectNewText text: String) {
        DispatchQueue.main.async {
            self.addItem(text)
            self.saveItems()
            self.monitor.postDarwinNotification()
        }
    }
    
    func clipboardMonitorDidReceiveDarwinNotification() {
        loadItems()
    }
}

// MARK: - Picture-in-Picture Clipboard Monitor

import Foundation
import UIKit
import AVKit
import Combine

/// Background clipboard monitoring using Picture-in-Picture
/// iOS 15+ teknolojisi ile uygulama kapalıyken bile clipboard izleme
@available(iOS 15.0, *)
public final class ClipboardPiPMonitor: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var monitoringDuration: TimeInterval = 0
    @Published public private(set) var itemsCaptured: Int = 0
    
    // MARK: - Private Properties
    
    private var pipController: AVPictureInPictureController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var monitoringTimer: Timer?
    private var changeCountTimer: Timer?
    private var startTime: Date?
    private var lastChangeCount: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    private let clipboardManager = ClipboardManager.shared
    
    // MARK: - Configuration
    
    public enum MonitoringMode {
        case continuous
        case timed(minutes: Int)
    }
    
    private var currentMode: MonitoringMode = .continuous
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ [PiPMonitor] Audio session setup failed: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// PiP monitoring başlat
    public func startMonitoring(mode: MonitoringMode = .continuous) {
        guard !isMonitoring else {
            print("⚠️ [PiPMonitor] Already monitoring")
            return
        }
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("❌ [PiPMonitor] PiP not supported on this device")
            return
        }
        
        currentMode = mode
        setupPiPController()
        startClipboardMonitoring()
        
        print("✅ [PiPMonitor] Started monitoring in \(mode) mode")
    }
    
    /// PiP monitoring durdur
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        pipController?.stopPictureInPicture()
        cleanupMonitoring()
        
        print("🛑 [PiPMonitor] Stopped monitoring. Captured \(itemsCaptured) items in \(Int(monitoringDuration))s")
    }
    
    // MARK: - PiP Setup
    
    private func setupPiPController() {
        // Sample buffer display layer oluştur
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect
        sampleBufferDisplayLayer = displayLayer
        
        // Monitoring image oluştur ve display layer'a ekle
        if let monitoringImage = createMonitoringImage() {
            displaySampleBuffer(from: monitoringImage, in: displayLayer)
        }
        
        // PiP controller oluştur
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        
        // PiP'i başlat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.pipController?.startPictureInPicture()
        }
    }
    
    private func createMonitoringImage() -> UIImage? {
        let size = CGSize(width: 400, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Arka plan
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // İkon
            if let icon = UIImage(systemName: "doc.on.clipboard.fill") {
                let iconSize: CGFloat = 80
                let iconRect = CGRect(
                    x: (size.width - iconSize) / 2,
                    y: 60,
                    width: iconSize,
                    height: iconSize
                )
                UIColor.systemBlue.setFill()
                icon.withTintColor(.systemBlue).draw(in: iconRect)
            }
            
            // Başlık
            let title = "Pano İzleniyor"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: 160),
                withAttributes: titleAttributes
            )
            
            // Alt yazı
            let subtitle = "Kopyalanan öğeler kaydediliyor"
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            subtitle.draw(
                at: CGPoint(x: (size.width - subtitleSize.width) / 2, y: 200),
                withAttributes: subtitleAttributes
            )
            
            // İstatistikler
            let stats = "📋 \(itemsCaptured) öğe • ⏱ \(formatDuration(monitoringDuration))"
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.systemGreen
            ]
            let statsSize = stats.size(withAttributes: statsAttributes)
            stats.draw(
                at: CGPoint(x: (size.width - statsSize.width) / 2, y: 240),
                withAttributes: statsAttributes
            )
        }
    }
    
    private func displaySampleBuffer(from image: UIImage, in layer: AVSampleBufferDisplayLayer) {
        guard let cgImage = image.cgImage else { return }
        
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            cgImage.width,
            cgImage.height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard let formatDescription = formatDescription else { return }
        
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if let sampleBuffer = sampleBuffer {
            if #available(iOS 18.0, *) {
                // iOS 18+ modern API - enqueue directly to renderer
                layer.sampleBufferRenderer.enqueue(sampleBuffer)
            } else {
                layer.enqueue(sampleBuffer)
            }
        }
    }
    
    // MARK: - Clipboard Monitoring
    
    private func startClipboardMonitoring() {
        isMonitoring = true
        startTime = Date()
        lastChangeCount = UIPasteboard.general.changeCount
        itemsCaptured = 0
        
        // Periyodik olarak clipboard değişikliklerini kontrol et
        changeCountTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
        
        // Süre sayacı
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMonitoringDuration()
        }
        
        // Timed mode ise otomatik durdur
        if case .timed(let minutes) = currentMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(minutes * 60)) { [weak self] in
                self?.stopMonitoring()
            }
        }
    }
    
    private func checkClipboardChanges() {
        let currentChangeCount = UIPasteboard.general.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        
        lastChangeCount = currentChangeCount
        
        // Yeni clipboard öğesini kaydet
        if let text = UIPasteboard.general.string, !text.isEmpty {
            clipboardManager.addItem(text)
            itemsCaptured += 1
            
            // Görseli güncelle
            updatePiPDisplay()
            
            print("📋 [PiPMonitor] Captured: \(text.prefix(50))...")
        }
    }
    
    private func updateMonitoringDuration() {
        guard let startTime = startTime else { return }
        monitoringDuration = Date().timeIntervalSince(startTime)
        updatePiPDisplay()
    }
    
    private func updatePiPDisplay() {
        guard let displayLayer = sampleBufferDisplayLayer,
              let updatedImage = createMonitoringImage() else { return }
        
        displaySampleBuffer(from: updatedImage, in: displayLayer)
    }
    
    private func cleanupMonitoring() {
        changeCountTimer?.invalidate()
        changeCountTimer = nil
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        isMonitoring = false
        startTime = nil
        
        sampleBufferDisplayLayer = nil
        pipController = nil
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

@available(iOS 15.0, *)
extension ClipboardPiPMonitor: AVPictureInPictureControllerDelegate {
    
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("🎬 [PiPMonitor] PiP will start")
    }
    
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("▶️ [PiPMonitor] PiP started")
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("⏹ [PiPMonitor] PiP stopped")
        cleanupMonitoring()
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("❌ [PiPMonitor] Failed to start PiP: \(error)")
        cleanupMonitoring()
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

@available(iOS 15.0, *)
extension ClipboardPiPMonitor: AVPictureInPictureSampleBufferPlaybackDelegate {
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // PiP play/pause kontrolü
        if playing {
            print("▶️ [PiPMonitor] Resumed")
        } else {
            print("⏸ [PiPMonitor] Paused")
        }
    }
    
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // Sınırsız süre
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // Render size değişikliği
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
