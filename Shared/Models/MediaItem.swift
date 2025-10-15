import Foundation
import UIKit
import UniformTypeIdentifiers

// Media tiplerini tanımlar
public enum MediaType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case file = "file" 
    case audio = "audio"
    case video = "video"
    case url = "url"
    
    public var displayName: String {
        switch self {
        case .text: return "Metin"
        case .image: return "Görsel"
        case .file: return "Dosya"
        case .audio: return "Ses"
        case .video: return "Video"
        case .url: return "Link"
        }
    }
    
    public var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        case .audio: return "waveform"
        case .video: return "video"
        case .url: return "link"
        }
    }
}

// Genişletilmiş clipboard item
public struct EnhancedClipboardItem: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var mediaType: MediaType
    public let createdDate: Date
    public var lastUsedDate: Date?
    
    // Content data
    public var textContent: String?
    public var fileURL: URL?
    public var thumbnailData: Data?
    public var fileSize: Int64?
    public var mimeType: String?
    
    // Metadata
    public var isPinned: Bool
    public var isFavorite: Bool
    public var category: ItemCategory
    public var tags: [String]
    public var note: String?
    public var usageCount: Int
    
    // AI generated data
    public var summary: String?
    public var extractedKeywords: [String]
    public var ocrText: String? // OCR'dan çıkarılan metin
    
    // Güvenlik
    public var isEncrypted: Bool
    public var requiresAuthentication: Bool
    
    public init(
        title: String = "",
        mediaType: MediaType,
        textContent: String? = nil,
        fileURL: URL? = nil,
        thumbnailData: Data? = nil,
        fileSize: Int64? = nil,
        mimeType: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.mediaType = mediaType
        self.textContent = textContent
        self.fileURL = fileURL
        self.thumbnailData = thumbnailData
        self.fileSize = fileSize
        self.mimeType = mimeType
        
        // Defaults
        self.createdDate = Date()
        self.lastUsedDate = nil
        self.isPinned = false
        self.isFavorite = false
        self.category = .text
        self.tags = []
        self.note = nil
        self.usageCount = 0
        self.summary = nil
        self.extractedKeywords = []
        self.ocrText = nil
        self.isEncrypted = false
        self.requiresAuthentication = false
    }
}

// File metadata helper
public struct FileMetadata: Codable {
    public let fileName: String
    public let fileExtension: String
    public let fileSize: Int64
    public let mimeType: String
    public let creationDate: Date?
    public let modificationDate: Date?
    
    public init(from url: URL) throws {
        let resourceValues = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentTypeKey,
            .creationDateKey,
            .contentModificationDateKey
        ])
        
        self.fileName = url.lastPathComponent
        self.fileExtension = url.pathExtension
        self.fileSize = Int64(resourceValues.fileSize ?? 0)
        self.mimeType = resourceValues.contentType?.identifier ?? "application/octet-stream"
        self.creationDate = resourceValues.creationDate
        self.modificationDate = resourceValues.contentModificationDate
    }
}

// Image metadata
public struct ImageMetadata: Codable {
    public let width: Int
    public let height: Int
    public let colorSpace: String?
    public let hasAlpha: Bool
    public let orientation: Int
    
    public init(from image: UIImage) {
        self.width = Int(image.size.width)
        self.height = Int(image.size.height)
        self.colorSpace = image.cgImage?.colorSpace?.name as String?
        self.hasAlpha = image.cgImage?.alphaInfo != .none
        self.orientation = image.imageOrientation.rawValue
    }
}

// Media processing durumu
public enum MediaProcessingStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
}

// Media processing task
public struct MediaProcessingTask: Identifiable, Codable {
    public let id: UUID
    public let itemId: UUID
    public let taskType: MediaProcessingTaskType
    public var status: MediaProcessingStatus
    public var progress: Double
    public var errorMessage: String?
    public let createdDate: Date
    public var completedDate: Date?
    
    public init(itemId: UUID, taskType: MediaProcessingTaskType) {
        self.id = UUID()
        self.itemId = itemId
        self.taskType = taskType
        self.status = .pending
        self.progress = 0.0
        self.errorMessage = nil
        self.createdDate = Date()
        self.completedDate = nil
    }
}

public enum MediaProcessingTaskType: String, Codable {
    case thumbnailGeneration = "thumbnail"
    case ocrProcessing = "ocr"
    case videoTranscoding = "transcoding"
    case audioTranscription = "transcription"
    case aiAnalysis = "analysis"
}