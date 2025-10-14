import SwiftUI

struct KeyboardClipboardItemView: View {
    let item: ClipboardItem
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var clipboardManager = ClipboardManager.shared
    
    var body: some View {
        Button(action: onTap) {
            ItemContentView(item: item, colorScheme: colorScheme)
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            contextMenuButtons
        }
    }
    
    private var contextMenuButtons: some View {
        Group {
            Button(action: {
                withAnimation {
                    togglePin()
                }
            }) {
                Label(item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                      systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            
            Button(action: {
                withAnimation {
                    toggleFavorite()
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
            
            Divider()
            
            Button(role: .destructive, action: deleteItem) {
                Label("Sil", systemImage: "trash")
            }
        }
    }
    
    private func togglePin() {
        clipboardManager.togglePinItem(item)
        HapticManager.trigger(.light)
    }
    
    private func toggleFavorite() {
        clipboardManager.toggleFavoriteItem(item)
        HapticManager.trigger(.light)
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
        HapticManager.trigger(.success)
    }
    
    private func deleteItem() {
        clipboardManager.deleteItem(item)
        HapticManager.trigger(.medium)
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
