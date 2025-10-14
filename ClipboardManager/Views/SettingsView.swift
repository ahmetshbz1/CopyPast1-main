import SwiftUI

struct SettingsView: View {
    @Binding var showSettings: Bool
    @AppStorage("maxClipboardItems") private var maxItems: Int = 50
    @AppStorage("autoDeleteDays") private var autoDeleteDays: Int = 30
    @AppStorage("enableAutoDelete") private var enableAutoDelete: Bool = false
    @StateObject private var clipboardManager = ClipboardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                // İstatistikler bölümü
                Section {
                    HStack {
                        Label("Toplam Öğe", systemImage: "doc.text.fill")
                        Spacer()
                        Text("\(clipboardManager.clipboardItems.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Sabitlenen", systemImage: "pin.fill")
                        Spacer()
                        Text("\(clipboardManager.clipboardItems.filter { $0.isPinned }.count)")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Label("Favoriler", systemImage: "star.fill")
                        Spacer()
                        Text("\(clipboardManager.clipboardItems.filter { $0.isFavorite }.count)")
                            .foregroundColor(.yellow)
                    }
                } header: {
                    Text("İstatistikler")
                }
                
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
                
                // Hızlı eylemler
                Section {
                    Button(role: .destructive, action: clearOldItems) {
                        Label("Eski Öğeleri Temizle", systemImage: "trash")
                    }
                    
                    Button(role: .destructive, action: clearAllExceptPinnedAndFavorites) {
                        Label("Sabitsiz Öğeleri Sil", systemImage: "trash.slash")
                    }
                } header: {
                    Text("Hızlı Eylemler")
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
        }
    }
    
    private func clearOldItems() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
        clipboardManager.clipboardItems.removeAll { item in
            !item.isPinned && !item.isFavorite && item.date < cutoffDate
        }
        clipboardManager.saveItems()
    }
    
    private func clearAllExceptPinnedAndFavorites() {
        clipboardManager.clipboardItems.removeAll { item in
            !item.isPinned && !item.isFavorite
        }
        clipboardManager.saveItems()
    }
}
