import Foundation
import CloudKit
import Combine


public protocol CloudSyncManagerProtocol {
    func syncToCloud(_ items: [EnhancedClipboardItem]) async throws
    func syncFromCloud() async throws -> [EnhancedClipboardItem]
    func deleteFromCloud(itemId: UUID) async throws
    func isCloudSyncAvailable() async -> Bool
    func resolveConflicts(_ localItems: [EnhancedClipboardItem], _ cloudItems: [EnhancedClipboardItem]) -> [EnhancedClipboardItem]
}

public enum CloudSyncError: LocalizedError {
    case notAvailable
    case notAuthenticated
    case quotaExceeded
    case networkError(Error)
    case conflictResolutionFailed
    case encryptionFailed
    case decryptionFailed
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud sync kullanılamıyor"
        case .notAuthenticated:
            return "iCloud'da oturum açın"
        case .quotaExceeded:
            return "iCloud depolama alanı dolu"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        case .conflictResolutionFailed:
            return "Conflict çözümlenemedi"
        case .encryptionFailed:
            return "Şifreleme başarısız"
        case .decryptionFailed:
            return "Şifre çözme başarısız"
        }
    }
}

public enum SyncStatus: String, CaseIterable {
    case idle = "idle"
    case syncing = "syncing"
    case error = "error"
    case completed = "completed"
    
    public var displayName: String {
        switch self {
        case .idle: return "Bekliyor"
        case .syncing: return "Senkronize ediliyor"
        case .error: return "Hata"
        case .completed: return "Tamamlandı"
        }
    }
}

public class CloudSyncManager: CloudSyncManagerProtocol, ObservableObject {
    
    @Published public var syncStatus: SyncStatus = .idle
    @Published public var lastSyncDate: Date?
    @Published public var syncProgress: Double = 0.0
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let securityManager = SecurityManager()
    
    // CloudKit record types
    private let recordType = "ClipboardItem"
    private let zoneID = CKRecordZone.ID(zoneName: "ClipboardZone", ownerName: CKCurrentUserDefaultName)
    
    public init() {
        self.container = CKContainer(identifier: "iCloud.com.ahmtcanx.clipboardmanager")
        self.privateDatabase = container.privateCloudDatabase
    }
    
    public func syncToCloud(_ items: [EnhancedClipboardItem]) async throws {
        guard await isCloudSyncAvailable() else {
            throw CloudSyncError.notAvailable
        }
        
        await MainActor.run { syncStatus = .syncing }
        
        do {
            try await ensureCustomZoneExists()
            
            let totalItems = items.count
            
            // Batch processing (CloudKit has limits)
            let batchSize = 100
            let batches = items.chunked(into: batchSize)
            
            for (index, batch) in batches.enumerated() {
                let records = try await createCloudKitRecords(from: batch)
                // Modern CloudKit async API ile kayıtları kaydet
                _ = try await privateDatabase.modifyRecords(saving: records, deleting: [])
                
                let processedItems = min((index * batchSize) + batch.count, totalItems)
                await MainActor.run {
                    syncProgress = Double(processedItems) / Double(totalItems)
                }
            }
            
            await MainActor.run {
                syncStatus = .completed
                lastSyncDate = Date()
                syncProgress = 1.0
            }
            
        } catch {
            await MainActor.run { syncStatus = .error }
            throw CloudSyncError.networkError(error)
        }
    }
    
    public func syncFromCloud() async throws -> [EnhancedClipboardItem] {
        guard await isCloudSyncAvailable() else {
            throw CloudSyncError.notAvailable
        }
        
        await MainActor.run { syncStatus = .syncing }
        
        do {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
            
            let cloudRecords = try await fetchRecordsFromCloud()
            let items = try await convertCloudKitRecords(cloudRecords)
            
            await MainActor.run {
                syncStatus = .completed
                lastSyncDate = Date()
            }
            
            return items
            
        } catch {
            await MainActor.run { syncStatus = .error }
            throw CloudSyncError.networkError(error)
        }
    }
    
    public func deleteFromCloud(itemId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: itemId.uuidString, zoneID: zoneID)
        
        do {
            try await privateDatabase.deleteRecord(withID: recordID)
        } catch {
            throw CloudSyncError.networkError(error)
        }
    }
    
    public func isCloudSyncAvailable() async -> Bool {
        do {
            let accountStatus = try await container.accountStatus()
            return accountStatus == .available
        } catch {
            return false
        }
    }
    
    public func resolveConflicts(_ localItems: [EnhancedClipboardItem], _ cloudItems: [EnhancedClipboardItem]) -> [EnhancedClipboardItem] {
        var mergedItems: [UUID: EnhancedClipboardItem] = [:]
        
        // Önce yerel öğeleri ekle
        for item in localItems {
            mergedItems[item.id] = item
        }
        
        // Cloud öğelerini kontrol et ve conflict çözümle
        for cloudItem in cloudItems {
            if let localItem = mergedItems[cloudItem.id] {
                // Conflict resolution: son değişiklik tarihi kazanır
                let resolvedItem = resolveConflict(local: localItem, cloud: cloudItem)
                mergedItems[cloudItem.id] = resolvedItem
            } else {
                // Cloud'da var ama local'da yok, ekle
                mergedItems[cloudItem.id] = cloudItem
            }
        }
        
        return Array(mergedItems.values)
    }
    
    // Private helper methods
    private func ensureCustomZoneExists() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        
        do {
            try await privateDatabase.save(zone)
        } catch let error as CKError {
            // Zone zaten varsa hata verme
            if error.code != .serverRecordChanged {
                throw error
            }
        }
    }
    
    private func createCloudKitRecords(from items: [EnhancedClipboardItem]) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        
        for item in items {
            let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            
            // Encrypt sensitive data
            let encryptedContent = try encryptIfNeeded(item.textContent ?? "")
            
            record["title"] = item.title as CKRecordValue
            record["encryptedContent"] = encryptedContent as CKRecordValue
            record["mediaType"] = item.mediaType.rawValue as CKRecordValue
            record["createdDate"] = item.createdDate as CKRecordValue
            record["lastUsedDate"] = item.lastUsedDate as CKRecordValue?
            record["isPinned"] = item.isPinned as CKRecordValue
            record["isFavorite"] = item.isFavorite as CKRecordValue
            record["category"] = item.category.rawValue as CKRecordValue
            record["tags"] = item.tags as CKRecordValue
            record["note"] = item.note as CKRecordValue?
            record["usageCount"] = item.usageCount as CKRecordValue
            record["summary"] = item.summary as CKRecordValue?
            record["extractedKeywords"] = item.extractedKeywords as CKRecordValue
            record["ocrText"] = item.ocrText as CKRecordValue?
            record["isEncrypted"] = item.isEncrypted as CKRecordValue
            record["requiresAuthentication"] = item.requiresAuthentication as CKRecordValue
            
            // File data handling
            if let fileURL = item.fileURL {
                let asset = CKAsset(fileURL: fileURL)
                record["fileAsset"] = asset
            }
            
            if let thumbnailData = item.thumbnailData {
                let tempURL = createTemporaryFile(with: thumbnailData, name: "thumbnail.jpg")
                let asset = CKAsset(fileURL: tempURL)
                record["thumbnailAsset"] = asset
            }
            
            records.append(record)
        }
        
        return records
    }
    
    private func convertCloudKitRecords(_ records: [CKRecord]) async throws -> [EnhancedClipboardItem] {
        var items: [EnhancedClipboardItem] = []
        
        for record in records {
            guard let title = record["title"] as? String,
                  let mediaTypeString = record["mediaType"] as? String,
                  let mediaType = MediaType(rawValue: mediaTypeString),
                  record["createdDate"] as? Date != nil,
                  let categoryString = record["category"] as? String,
                  let category = ItemCategory(rawValue: categoryString) else {
                continue
            }
            
            let encryptedContent = record["encryptedContent"] as? String ?? ""
            let textContent = try decryptIfNeeded(encryptedContent)
            
            var item = EnhancedClipboardItem(
                title: title,
                mediaType: mediaType,
                textContent: textContent
            )
            
            // Set other properties
            item.lastUsedDate = record["lastUsedDate"] as? Date
            item.isPinned = record["isPinned"] as? Bool ?? false
            item.isFavorite = record["isFavorite"] as? Bool ?? false
            item.category = category
            item.tags = record["tags"] as? [String] ?? []
            item.note = record["note"] as? String
            item.usageCount = record["usageCount"] as? Int ?? 0
            item.summary = record["summary"] as? String
            item.extractedKeywords = record["extractedKeywords"] as? [String] ?? []
            item.ocrText = record["ocrText"] as? String
            item.isEncrypted = record["isEncrypted"] as? Bool ?? false
            item.requiresAuthentication = record["requiresAuthentication"] as? Bool ?? false
            
            // Handle file assets
            if let fileAsset = record["fileAsset"] as? CKAsset {
                item.fileURL = fileAsset.fileURL
            }
            
            if let thumbnailAsset = record["thumbnailAsset"] as? CKAsset,
               let thumbnailURL = thumbnailAsset.fileURL {
                item.thumbnailData = try Data(contentsOf: thumbnailURL)
            }
            
            items.append(item)
        }
        
        return items
    }
    
    private func resolveConflict(local: EnhancedClipboardItem, cloud: EnhancedClipboardItem) -> EnhancedClipboardItem {
        // Simple conflict resolution: most recently used wins
        let localDate = local.lastUsedDate ?? local.createdDate
        let cloudDate = cloud.lastUsedDate ?? cloud.createdDate
        
        return localDate > cloudDate ? local : cloud
    }
    
    private func encryptIfNeeded(_ content: String) throws -> String {
        // Hassas içerikse şifrele
        let privacyManager = PrivacyManager()
        if privacyManager.isSensitiveContent(content) {
            let data = content.data(using: .utf8) ?? Data()
            let encryptedData = try securityManager.encryptData(data)
            return encryptedData.base64EncodedString()
        }
        return content
    }
    
    private func decryptIfNeeded(_ content: String) throws -> String {
        // Base64 string ise decrypt et
        if let data = Data(base64Encoded: content) {
            do {
                let decryptedData = try securityManager.decryptData(data)
                return String(data: decryptedData, encoding: .utf8) ?? content
            } catch {
                // Decrypt başarısızsa orijinali döndür
                return content
            }
        }
        return content
    }
    
    private func createTemporaryFile(with data: Data, name: String) -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: tempURL)
        return tempURL
    }
    
    // Modern CloudKit async API: Kayıtları çek
    private func fetchRecordsFromCloud() async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var nextCursor: CKQueryOperation.Cursor?
        
        repeat {
            if let cursor = nextCursor {
                // Cursor ile devam et
                let (matchResults, newCursor) = try await privateDatabase.records(continuingMatchFrom: cursor)
                for (_, res) in matchResults {
                    if case .success(let record) = res { allRecords.append(record) }
                }
                nextCursor = newCursor
            } else {
                // İlk sorgu
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
                let (matchResults, newCursor) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
                for (_, res) in matchResults {
                    if case .success(let record) = res { allRecords.append(record) }
                }
                nextCursor = newCursor
            }
        } while nextCursor != nil
        
        return allRecords
    }
}

// Array extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}