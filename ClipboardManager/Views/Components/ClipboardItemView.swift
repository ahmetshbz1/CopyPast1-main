import SwiftUI

struct ClipboardItemView: View {
    let item: ClipboardItem
    let showToastMessage: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var showEditSheet = false
    @State private var editedText = ""
    @StateObject private var clipboardManager = ClipboardManager.shared
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            
            Button(action: {
                editedText = item.text
                showEditSheet = true
            }) {
                Label("Düzenle", systemImage: "pencil")
            }
            
            Button(action: {
                withAnimation {
                    deleteItem(item)
                }
            }) {
                Label("Sil", systemImage: "trash")
            }
            .tint(.red)
            
            Button(action: shareItem) {
                Label("Paylaş", systemImage: "square.and.arrow.up")
            }
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