import SwiftUI

struct EditItemSheet: View {
    let item: ClipboardItem
    @Binding var editedText: String
    @Binding var showEditSheet: Bool
    @StateObject private var clipboardManager = ClipboardManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $editedText)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer()
            }
            .navigationTitle("Metni Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveEditedItem()
                    }
                }
            }
        }
    }
    
    private func saveEditedItem() {
        if let index = clipboardManager.clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardManager.clipboardItems[index].text = editedText
            clipboardManager.saveItems()
        }
        showEditSheet = false
    }
}