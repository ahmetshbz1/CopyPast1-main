import SwiftUI

struct ClipboardItemView: View {
    let item: ClipboardItem
    let showToastMessage: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var showEditSheet = false
    @State private var showQRCode = false
    @State private var editedText = ""
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
                withAnimation {
                    deleteItem(item)
                }
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
