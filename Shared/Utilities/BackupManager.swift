import Foundation

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
        let backup = BackupData(items: items)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }
    
    /// JSON'dan import eder
    public static func importFromJSON(data: Data) throws -> [ClipboardItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)
        return backup.items
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
        try data.write(to: tempURL)
        return tempURL
    }
}
