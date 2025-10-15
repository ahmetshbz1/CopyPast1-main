import SwiftUI
import UniformTypeIdentifiers
import Security

struct ClipboardItemView: View {
    let item: ClipboardItem
    let showToastMessage: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var showEditSheet = false
    @State private var showQRCode = false
    @State private var editedText = ""
    @State private var showDeleteConfirmation = false
    @StateObject private var clipboardManager = ClipboardManager.shared
    
    var body: some View {
        Button(action: {
            HapticManager.trigger(.medium)
            UIPasteboard.general.string = item.text
            clipboardManager.registerUsage(byText: item.text)
            showToastMessage("Kopyalandı")
        }) {
            ItemContentView(item: item, colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            contextMenuButtons
        }
        .sheet(isPresented: $showEditSheet) {
            EditItemSheet(item: item, editedText: $editedText, showEditSheet: $showEditSheet)
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeView(text: item.text, showQRCode: $showQRCode)
        }
        .confirmationDialog(
            "Bu öğeyi silmek istediğinizden emin misiniz?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                withAnimation {
                    deleteItem(item)
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }
    
    private var contextMenuButtons: some View {
        Group {
            Button(action: {
                withAnimation {
                    togglePin(item)
                }
            }) {
                Label(item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                      systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            
            Button(action: {
                withAnimation {
                    toggleFavorite(item)
                }
            }) {
                Label(item.isFavorite ? "Favorilerden Çıkar" : "Favorilere Ekle",
                      systemImage: item.isFavorite ? "star.slash" : "star")
            }
            
            Divider()
            
            Menu {
                Button(action: { copyAs(.uppercase) }) {
                    Label("Büyük Harf Kopyala", systemImage: "textformat.size.larger")
                }
                Button(action: { copyAs(.lowercase) }) {
                    Label("Küçük Harf Kopyala", systemImage: "textformat.size.smaller")
                }
                Button(action: { copyAs(.firstLine) }) {
                    Label("İlk Satırı Kopyala", systemImage: "text.alignleft")
                }
                Button(action: { copyAs(.lastLine) }) {
                    Label("Son Satırı Kopyala", systemImage: "text.alignright")
                }
            } label: {
                Label("Farklı Kopyala...", systemImage: "doc.on.doc")
            }
            
            // AI İşlemleri
            Menu {
                Button(action: { aiSummarize() }) {
                    Label("Özetle", systemImage: "text.alignleft")
                }
                Menu {
                    Button(action: { aiTranslate(to: "English") }) { Text("İngilizce") }
                    Button(action: { aiTranslate(to: "Turkish") }) { Text("Türkçe") }
                } label: {
                    Label("Çevir", systemImage: "globe")
                }
                Menu {
                    Button(action: { aiImprove(style: .formal) }) { Text("Resmi") }
                    Button(action: { aiImprove(style: .casual) }) { Text("Günlük") }
                    Button(action: { aiImprove(style: .business) }) { Text("İş") }
                    Button(action: { aiImprove(style: .academic) }) { Text("Akademik") }
                    Button(action: { aiImprove(style: .creative) }) { Text("Yaratıcı") }
                } label: {
                    Label("İyileştir", systemImage: "wand.and.stars")
                }
                Button(action: { aiExtractKeywords() }) {
                    Label("Anahtar Kelime Çıkar", systemImage: "tag")
                }
            } label: {
                Label("Yapay Zeka", systemImage: "brain.head.profile")
            }
            
            Button(action: { showQRCode = true }) {
                Label("QR Kod Oluştur", systemImage: "qrcode")
            }
            
            Button(action: {
                editedText = item.text
                showEditSheet = true
            }) {
                Label("Düzenle", systemImage: "pencil")
            }
            
            Divider()
            
            Button(action: shareItem) {
                Label("Paylaş", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Label("Sil", systemImage: "trash")
            }
            .tint(.red)
        }
    }
    
    private func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
    }
    
    private func toggleFavorite(_ item: ClipboardItem) {
        clipboardManager.toggleFavoriteItem(item)
    }
    
    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.clipboardItems.removeAll(where: { $0.id == item.id })
        clipboardManager.saveItems()
    }
    
    private enum CopyMode {
        case uppercase, lowercase, firstLine, lastLine
    }
    
    private func copyAs(_ mode: CopyMode) {
        let textToCopy: String
        switch mode {
        case .uppercase:
            textToCopy = item.text.uppercasedTr()
        case .lowercase:
            textToCopy = item.text.lowercasedTr()
        case .firstLine:
            textToCopy = item.text.firstLine
        case .lastLine:
            textToCopy = item.text.lastLine
        }
        
        UIPasteboard.general.string = textToCopy
        clipboardManager.registerUsage(byText: item.text)
        
        let message: String
        switch mode {
        case .uppercase: message = "Büyük harfle kopyalandı"
        case .lowercase: message = "Küçük harfle kopyalandı"
        case .firstLine: message = "İlk satır kopyalandı"
        case .lastLine: message = "Son satır kopyalandı"
        }
        showToastMessage(message)
    }
    
    private func shareItem() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [item.text],
            applicationActivities: nil
        )
        
        if let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - AI Helpers
extension ClipboardItemView {
    private func readAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ahmtcanx.clipboardmanager",
            kSecAttrAccount as String: "openai_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var res: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &res)
        if status != errSecSuccess { return nil }
        guard let data = res as? Data, let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }
    
    private func aiSummarize() {
        guard let key = readAPIKey(), !key.isEmpty else {
            showToastMessage("OpenAI API anahtarı gerekli (Ayarlar > Yapay Zeka)")
            return
        }
        Task { @MainActor in
            do {
                let service = OpenAIService(apiKey: key)
                let summary = try await service.summarizeText(item.text)
                // Özet yeni bir öğe olarak eklensin
                ClipboardManager.shared.addItem(summary)
                ClipboardManager.shared.saveItems()
                showToastMessage("Özet eklendi")
            } catch {
                showToastMessage("Özetleme başarısız")
            }
        }
    }
    
    private func aiTranslate(to language: String) {
        guard let key = readAPIKey(), !key.isEmpty else {
            showToastMessage("OpenAI API anahtarı gerekli (Ayarlar > Yapay Zeka)")
            return
        }
        Task { @MainActor in
            do {
                let service = OpenAIService(apiKey: key)
                let translated = try await service.translateText(item.text, to: language)
                ClipboardManager.shared.addItem(translated)
                ClipboardManager.shared.saveItems()
                showToastMessage("Çeviri eklendi")
            } catch {
                showToastMessage("Çeviri başarısız")
            }
        }
    }
    
    private func aiImprove(style: TextStyle) {
        guard let key = readAPIKey(), !key.isEmpty else {
            showToastMessage("OpenAI API anahtarı gerekli (Ayarlar > Yapay Zeka)")
            return
        }
        Task { @MainActor in
            do {
                let service = OpenAIService(apiKey: key)
                let improved = try await service.improveText(item.text, style: style)
                ClipboardManager.shared.addItem(improved)
                ClipboardManager.shared.saveItems()
                showToastMessage("Metin iyileştirildi")
            } catch {
                showToastMessage("İyileştirme başarısız")
            }
        }
    }
    
    private func aiExtractKeywords() {
        guard let key = readAPIKey(), !key.isEmpty else {
            showToastMessage("OpenAI API anahtarı gerekli (Ayarlar > Yapay Zeka)")
            return
        }
        Task { @MainActor in
            do {
                let service = OpenAIService(apiKey: key)
                let keywords = try await service.extractKeywords(item.text)
                // Etiketlere ekle
                var added = 0
                for k in keywords {
                    if !ClipboardManager.shared.clipboardItems.first(where: { $0.id == item.id })!.tags.contains(k) {
                        ClipboardManager.shared.addTag(k, to: item)
                        added += 1
                    }
                }
                ClipboardManager.shared.saveItems()
                showToastMessage(added > 0 ? "\(added) etiket eklendi" : "Yeni etiket yok")
            } catch {
                showToastMessage("Anahtar kelime çıkarma başarısız")
            }
        }
    }
}
