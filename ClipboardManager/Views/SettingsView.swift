import SwiftUI

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
    @State private var showExportActivity = false
    @State private var showImportPicker = false
    @State private var exportFileURL: URL?
    
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
                        Label("Otomatik Temizleme", systemImage: "trash.clock")
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
            .sheet(isPresented: $showExportActivity) {
                if let url = exportFileURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
        }
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
        do {
            let url = try BackupManager.createTemporaryBackupFile(items: clipboardManager.clipboardItems)
            exportFileURL = url
            showExportActivity = true
            HapticManager.trigger(.success)
        } catch {
            print("Export error: \(error)")
            HapticManager.trigger(.error)
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importData(from: url)
        case .failure(let error):
            print("Import picker error: \(error)")
            HapticManager.trigger(.error)
        }
    }
    
    private func importData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let items = try BackupManager.importFromJSON(data: data)
            
            // Mevcut itemlara ekle (duplicate kontrolü yaparak)
            for item in items {
                if !clipboardManager.clipboardItems.contains(where: { $0.id == item.id }) {
                    clipboardManager.clipboardItems.append(item)
                }
            }
            
            clipboardManager.saveItems()
            HapticManager.triggerCombo([.success, .light])
        } catch {
            print("Import error: \(error)")
            HapticManager.trigger(.error)
        }
    }
}

// MARK: - ActivityViewController Wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // iPad için popover ayarı
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
