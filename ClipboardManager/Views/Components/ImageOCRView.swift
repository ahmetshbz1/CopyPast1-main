import SwiftUI
import PhotosUI

struct ImageOCRView: View {
    @Binding var isPresented: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label("Görsel Seç", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                
                if isProcessing { ProgressView("İşleniyor...") }
                if let errorMessage { Text(errorMessage).foregroundColor(.red).font(.footnote) }
                Spacer()
            }
            .padding()
            .navigationTitle("Görselden Metin")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { isPresented = false }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task { await handleSelection(item: newItem) }
            }
        }
    }
    
    @MainActor
    private func handleSelection(item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Görsel okunamadı"
                return
            }
            let ocrText = try await MediaProcessor().extractTextFromImage(data)
            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Metin bulunamadı"
                return
            }
            ClipboardManager.shared.addItem(ocrText)
            ClipboardManager.shared.saveItems()
            isPresented = false
        } catch {
            errorMessage = "OCR başarısız: \(error.localizedDescription)"
        }
    }
}
