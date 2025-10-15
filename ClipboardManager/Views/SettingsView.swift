import SwiftUI
import Security

struct SettingsView: View {
    @Binding var showSettings: Bool
    @AppStorage("maxClipboardItems") private var maxItems: Int = 50
    @AppStorage("autoDeleteDays") private var autoDeleteDays: Int = 30
    @AppStorage("enableAutoDelete") private var enableAutoDelete: Bool = false
    @StateObject private var clipboardManager = ClipboardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showClearOldAlert = false
    @State private var showClearUnpinnedAlert = false
    @State private var itemsToDelete = 0
    @State private var showExportPicker = false
    @State private var showImportPicker = false
    @State private var exportDocument: BackupDocument?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Depolama ayarları
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Maksimum Öğe Sayısı")
                            Spacer()
                            Text("\(maxItems)")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(maxItems) },
                            set: { maxItems = Int($0) }
                        ), in: 10...200, step: 10)
                        .tint(.blue)
                        
                        Text("Pano en fazla \(maxItems) öğe saklayacak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Depolama")
                } footer: {
                    Text("Limit aşıldığında en eski öğeler silinir (sabitli olanlar hariç)")
                }
                
                // Otomatik temizleme
                Section {
                    Toggle(isOn: $enableAutoDelete) {
                        Label("Otomatik Temizleme", systemImage: "clock.badge.xmark")
                    }
                    .tint(.red)
                    
                    if enableAutoDelete {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Süre")
                                Spacer()
                                Text("\(autoDeleteDays) gün")
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(autoDeleteDays) },
                                set: { autoDeleteDays = Int($0) }
                            ), in: 1...90, step: 1)
                            .tint(.red)
                            
                            Text("\(autoDeleteDays) günden eski öğeler otomatik silinir")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Temizleme")
                } footer: {
                    Text("Sabitlenen ve favori öğeler otomatik temizlemeden etkilenmez")
                }
                
                // Yedekleme
                Section {
                    Button(action: exportData) {
                        Label("Verileri Dışa Aktar", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showImportPicker = true }) {
                        Label("Verileri İçe Aktar", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Yedekleme")
                } footer: {
                    Text("Tüm pano verilerinizi JSON formatında kaydedip geri yükleyebilirsiniz")
                }
                
                // Hızlı eylemler
                Section {
                    Button(action: {
                        calculateOldItems()
                        showClearOldAlert = true
                    }) {
                        HStack {
                            Label("Eski Öğeleri Temizle", systemImage: "trash")
                            Spacer()
                            if itemsToDelete > 0 {
                                Text("\(itemsToDelete)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                    }
                    .foregroundColor(.red)
                    
                    Button(action: {
                        calculateUnpinnedItems()
                        showClearUnpinnedAlert = true
                    }) {
                        HStack {
                            Label("Sabitsiz Öğeleri Sil", systemImage: "trash.slash")
                            Spacer()
                            let count = clipboardManager.clipboardItems.filter { !$0.isPinned && !$0.isFavorite }.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.orange))
                            }
                        }
                    }
                    .foregroundColor(.orange)
                } header: {
                    Text("Hızlı Eylemler")
                } footer: {
                    Text("\(autoDeleteDays) günden eski \(itemsToDelete) öğe silinecek")
                }
                
                // Yapay Zeka ayarları
                Section {
                    AISettingsSection()
                } header: {
                    Text("Yapay Zeka")
                } footer: {
                    Text("OpenAI API anahtarınızı güvenli şekilde saklayın ve metin işlemleri için kullanın")
                }
                
                // Uygulama bilgisi
                Section {
                    HStack {
                        Label("Versiyon", systemImage: "app.badge")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/AhmetShbz")!) {
                        Label("GitHub", systemImage: "link")
                    }
                } header: {
                    Text("Uygulama")
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tamam") {
                        showSettings = false
                    }
                }
            }
            .alert("Eski Öğeleri Temizle", isPresented: $showClearOldAlert) {
                Button("Vazgeç", role: .cancel) { }
                Button("Temizle", role: .destructive) {
                    clearOldItems()
                }
            } message: {
                Text("\(autoDeleteDays) günden eski \(itemsToDelete) öğe silinecek. Bu işlem geri alınamaz!")
            }
            .alert("Sabitsiz Öğeleri Sil", isPresented: $showClearUnpinnedAlert) {
                Button("Vazgeç", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    clearAllExceptPinnedAndFavorites()
                }
            } message: {
                let count = clipboardManager.clipboardItems.filter { !$0.isPinned && !$0.isFavorite }.count
                Text("Sabitsiz ve favori olmayan \(count) öğe silinecek. Bu işlem geri alınamaz!")
            }
            .fileExporter(
                isPresented: $showExportPicker,
                document: exportDocument,
                contentType: .json,
                defaultFilename: BackupManager.generateBackupFileName()
            ) { result in
                switch result {
                case .success(let url):
                    print("File saved to: \(url)")
                    alertMessage = "Veriler başarıyla dışa aktarıldı"
                    showSuccessAlert = true
                    HapticManager.trigger(.success)
                case .failure(let error):
                    print("Export error: \(error)")
                    alertMessage = "Dışa aktarma başarısız: \(error.localizedDescription)"
                    showErrorAlert = true
                    HapticManager.trigger(.error)
                }
                exportDocument = nil
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Başarılı", isPresented: $showSuccessAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Hata", isPresented: $showErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - AI Settings Section (inline)
    @ViewBuilder private func AISettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("OpenAI API Key", text: $aiApiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 14))
            
            HStack {
                Button {
                    do {
                        try setAIApiKey(aiApiKey)
                        showToastInline(text: "API anahtarı kaydedildi")
                    } catch {
                        showToastInline(text: "Kaydetme başarısız")
                    }
                } label: {
                    Label("Kaydet", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                
                Button(role: .destructive) {
                    do {
                        try removeAIApiKey()
                        aiApiKey = ""
                        showToastInline(text: "API anahtarı silindi")
                    } catch {
                        showToastInline(text: "Silme başarısız")
                    }
                } label: {
                    Label("Temizle", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            if let key = try? getAIApiKey() { aiApiKey = key ?? "" }
        }
        .padding(.vertical, 4)
    }
    
    @State private var aiApiKey: String = ""
    
    private func showToastInline(text: String) {
        // Ayarlarda basit bir görsel geribildirim için Alert yerine log; istersen snackbar ekleyebiliriz
        print(text)
    }
    
    // Keychain helpers (inline)
    private func setAIApiKey(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ahmtcanx.clipboardmanager",
            kSecAttrAccount as String: "openai_api_key"
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    
    private func getAIApiKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ahmtcanx.clipboardmanager",
            kSecAttrAccount as String: "openai_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var res: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &res)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        guard let data = res as? Data, let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
    
    private func removeAIApiKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ahmtcanx.clipboardmanager",
            kSecAttrAccount as String: "openai_api_key"
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    private func calculateOldItems() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
        itemsToDelete = clipboardManager.clipboardItems.filter { item in
            !item.isPinned && !item.isFavorite && item.date < cutoffDate
        }.count
    }
    
    private func calculateUnpinnedItems() {
        itemsToDelete = clipboardManager.clipboardItems.filter { !$0.isPinned && !$0.isFavorite }.count
    }
    
    private func clearOldItems() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
        let beforeCount = clipboardManager.clipboardItems.count
        
        clipboardManager.clipboardItems.removeAll { item in
            !item.isPinned && !item.isFavorite && item.date < cutoffDate
        }
        
        let deletedCount = beforeCount - clipboardManager.clipboardItems.count
        clipboardManager.saveItems()
        
        // Toast göster
        if deletedCount > 0 {
            DispatchQueue.main.async {
                clipboardManager.objectWillChange.send()
            }
        }
    }
    
    private func clearAllExceptPinnedAndFavorites() {
        let beforeCount = clipboardManager.clipboardItems.count
        
        clipboardManager.clipboardItems.removeAll { item in
            !item.isPinned && !item.isFavorite
        }
        
        let deletedCount = beforeCount - clipboardManager.clipboardItems.count
        clipboardManager.saveItems()
        
        // Toast göster
        if deletedCount > 0 {
            DispatchQueue.main.async {
                clipboardManager.objectWillChange.send()
            }
        }
    }
    
    private func exportData() {
        guard !clipboardManager.clipboardItems.isEmpty else {
            alertMessage = "Dışa aktarılacak öğe yok"
            showErrorAlert = true
            HapticManager.trigger(.warning)
            return
        }
        
        do {
            let data = try BackupManager.exportToJSON(items: clipboardManager.clipboardItems)
            exportDocument = BackupDocument(data: data)
            showExportPicker = true
        } catch {
            print("Export error: \(error)")
            alertMessage = "Dışa aktarma sırasında bir hata oluştu: \(error.localizedDescription)"
            showErrorAlert = true
            HapticManager.trigger(.error)
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Güvenlik kapsamlı dosya erişimi
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            importData(from: url)
        case .failure(let error):
            print("Import picker error: \(error)")
            alertMessage = "Dosya seçimi sırasında bir hata oluştu: \(error.localizedDescription)"
            showErrorAlert = true
            HapticManager.trigger(.error)
        }
    }
    
    private func importData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let items = try BackupManager.importFromJSON(data: data)
            
            var newItemsCount = 0
            var duplicateCount = 0
            
            // Mevcut itemlara ekle (duplicate kontrolü yaparak)
            for item in items {
                if !clipboardManager.clipboardItems.contains(where: { $0.id == item.id }) {
                    clipboardManager.clipboardItems.append(item)
                    newItemsCount += 1
                } else {
                    duplicateCount += 1
                }
            }
            
            clipboardManager.saveItems()
            
            // Başarı mesajı
            if newItemsCount > 0 {
                alertMessage = "\(newItemsCount) öğe başarıyla içe aktarıldı."
                if duplicateCount > 0 {
                    alertMessage += "\n\(duplicateCount) öğe zaten mevcut olduğu için atlandı."
                }
                showSuccessAlert = true
                HapticManager.triggerCombo([.success, .light])
            } else {
                alertMessage = "Tüm öğeler zaten mevcut. Yeni öğe eklenmedi."
                showErrorAlert = true
                HapticManager.trigger(.warning)
            }
        } catch DecodingError.keyNotFound(let key, let context) {
            print("Import decode error - missing key: \(key), context: \(context)")
            alertMessage = "Dosya formatı hatalı. Eksik alan: \(key.stringValue)"
            showErrorAlert = true
            HapticManager.trigger(.error)
        } catch DecodingError.typeMismatch(let type, let context) {
            print("Import decode error - type mismatch: \(type), context: \(context)")
            alertMessage = "Dosya formatı uyumsuz. Geçersiz veri tipi bulundu."
            showErrorAlert = true
            HapticManager.trigger(.error)
        } catch {
            print("Import error: \(error)")
            alertMessage = "İçe aktarma sırasında bir hata oluştu: \(error.localizedDescription)"
            showErrorAlert = true
            HapticManager.trigger(.error)
        }
    }
}

// MARK: - ActivityViewController Wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: (() -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Completion handler
        controller.completionWithItemsHandler = { _, completed, _, error in
            if let error = error {
                print("Share error: \(error)")
            }
            if completed {
                print("Share completed successfully")
            }
            onComplete?()
        }
        
        // iPad için popover ayarı
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(
                x: UIScreen.main.bounds.midX,
                y: UIScreen.main.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Güncelleme gerekmiyor
    }
}
