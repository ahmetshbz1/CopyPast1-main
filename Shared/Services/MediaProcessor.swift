import Foundation
import UIKit
import Vision
import AVFoundation
import UniformTypeIdentifiers

public protocol MediaProcessorProtocol {
    func generateThumbnail(for item: EnhancedClipboardItem) async throws -> Data
    func extractTextFromImage(_ imageData: Data) async throws -> String
    func processAudioFile(_ url: URL) async throws -> String
    func compressVideo(_ url: URL, quality: VideoQuality) async throws -> URL
}

public enum VideoQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var displayName: String {
        switch self {
        case .low: return "Düşük"
        case .medium: return "Orta"
        case .high: return "Yüksek"
        }
    }
}

public enum MediaProcessorError: LocalizedError {
    case unsupportedFileType
    case fileNotFound
    case processingFailed(String)
    case insufficientStorage
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Desteklenmeyen dosya türü"
        case .fileNotFound:
            return "Dosya bulunamadı"
        case .processingFailed(let message):
            return "İşleme başarısız: \(message)"
        case .insufficientStorage:
            return "Yetersiz depolama alanı"
        case .permissionDenied:
            return "İzin reddedildi"
        }
    }
}

public class MediaProcessor: MediaProcessorProtocol {
    
    private let fileManager = FileManager.default
    private let thumbnailSize = CGSize(width: 300, height: 300)
    
    public init() {}
    
    public func generateThumbnail(for item: EnhancedClipboardItem) async throws -> Data {
        switch item.mediaType {
        case .image:
            return try await generateImageThumbnail(item)
        case .video:
            return try await generateVideoThumbnail(item)
        case .file:
            return try await generateFileThumbnail(item)
        default:
            throw MediaProcessorError.unsupportedFileType
        }
    }
    
    public func extractTextFromImage(_ imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw MediaProcessorError.processingFailed("Görsel okunamadı")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { observation in
                    try? observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            request.recognitionLanguages = ["tr-TR", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func processAudioFile(_ url: URL) async throws -> String {
        // Audio transcription placeholder - gerçek implementasyon için Apple's Speech framework
        return "Ses dosyası transkripsiyon özelliği yakında..."
    }
    
    public func compressVideo(_ url: URL, quality: VideoQuality) async throws -> URL {
        let outputURL = createTemporaryURL(for: "compressed_video.mp4")
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let exportSession = AVAssetExportSession(
                asset: AVAsset(url: url),
                presetName: getExportPreset(for: quality)
            ) else {
                continuation.resume(throwing: MediaProcessorError.processingFailed("Export session oluşturulamadı"))
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? MediaProcessorError.processingFailed("Bilinmeyen hata")
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: MediaProcessorError.processingFailed("İşlem iptal edildi"))
                default:
                    continuation.resume(throwing: MediaProcessorError.processingFailed("Beklenmeyen durum"))
                }
            }
        }
    }
    
    // Private helper methods
    private func generateImageThumbnail(_ item: EnhancedClipboardItem) async throws -> Data {
        guard let url = item.fileURL,
              let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            throw MediaProcessorError.fileNotFound
        }
        
        let thumbnail = await generateThumbnail(from: image)
        guard let data = thumbnail.jpegData(compressionQuality: 0.8) else {
            throw MediaProcessorError.processingFailed("Thumbnail oluşturulamadı")
        }
        
        return data
    }
    
    private func generateVideoThumbnail(_ item: EnhancedClipboardItem) async throws -> Data {
        guard let url = item.fileURL else {
            throw MediaProcessorError.fileNotFound
        }
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = thumbnailSize
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: MediaProcessorError.processingFailed("Thumbnail oluşturulamadı"))
                    return
                }
                
                let thumbnail = UIImage(cgImage: cgImage)
                guard let data = thumbnail.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(throwing: MediaProcessorError.processingFailed("Thumbnail verisi oluşturulamadı"))
                    return
                }
                
                continuation.resume(returning: data)
            }
        }
    }
    
    private func generateFileThumbnail(_ item: EnhancedClipboardItem) async throws -> Data {
        // Dosya türüne göre icon oluştur
        let iconImage = createFileIcon(for: item.mimeType ?? "application/octet-stream")
        guard let data = iconImage.pngData() else {
            throw MediaProcessorError.processingFailed("Icon oluşturulamadı")
        }
        return data
    }
    
    @MainActor
    private func generateThumbnail(from image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }
    
    private func createFileIcon(for mimeType: String) -> UIImage {
        let systemName: String
        
        if mimeType.hasPrefix("image/") {
            systemName = "photo"
        } else if mimeType.hasPrefix("video/") {
            systemName = "video"
        } else if mimeType.hasPrefix("audio/") {
            systemName = "waveform"
        } else if mimeType.contains("pdf") {
            systemName = "doc.richtext"
        } else if mimeType.contains("text") {
            systemName = "doc.text"
        } else {
            systemName = "doc"
        }
        
        return UIImage(systemName: systemName) ?? UIImage(systemName: "doc")!
    }
    
    private func getExportPreset(for quality: VideoQuality) -> String {
        switch quality {
        case .low: return AVAssetExportPresetLowQuality
        case .medium: return AVAssetExportPresetMediumQuality
        case .high: return AVAssetExportPresetHighestQuality
        }
    }
    
    private func createTemporaryURL(for fileName: String) -> URL {
        let temporaryDirectory = fileManager.temporaryDirectory
        return temporaryDirectory.appendingPathComponent(fileName)
    }
}
