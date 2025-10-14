import Foundation

public enum BackupError: LocalizedError {
    case emptyItems
    case invalidData
    case fileWriteFailed
    case fileReadFailed
    
    public var errorDescription: String? {
        switch self {
        case .emptyItems:
            return "Dışa aktarılacak öğe bulunamadı"
        case .invalidData:
            return "Dosya formatı geçersiz"
        case .fileWriteFailed:
            return "Dosya yazılamadı"
        case .fileReadFailed:
            return "Dosya okunamadı"
        }
    }
}

public struct BackupManager {
    
    public struct BackupData: Codable {
        let version: String
        let exportDate: Date
        let itemsCount: Int
        let items: [ClipboardItem]
        
        init(items: [ClipboardItem]) {
            self.version = "1.0"
            self.exportDate = Date()
            self.itemsCount = items.count
            self.items = items
        }
    }
    
    /// JSON olarak export eder
    public static func exportToJSON(items: [ClipboardItem]) throws -> Data {
        guard !items.isEmpty else {
            throw BackupError.emptyItems
        }
        
        let backup = BackupData(items: items)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            return try encoder.encode(backup)
        } catch {
            print("Encoding error: \(error)")
            throw error
        }
    }
    
    /// JSON'dan import eder
    public static func importFromJSON(data: Data) throws -> [ClipboardItem] {
        guard !data.isEmpty else {
            throw BackupError.invalidData
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let backup = try decoder.decode(BackupData.self, from: data)
            
            guard !backup.items.isEmpty else {
                throw BackupError.emptyItems
            }
            
            return backup.items
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw error
        } catch {
            print("Import error: \(error)")
            throw BackupError.invalidData
        }
    }
    
    /// Dosya adı oluşturur
    public static func generateBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = formatter.string(from: Date())
        return "CopyPast_Backup_\(dateString).json"
    }
    
    /// Temporary dosya yolu döndürür
    public static func createTemporaryBackupFile(items: [ClipboardItem]) throws -> URL {
        let data = try exportToJSON(items: items)
        let fileName = generateBackupFileName()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            print("File write error: \(error)")
            throw BackupError.fileWriteFailed
        }
    }
}
