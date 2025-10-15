import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager.shared
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showAboutSheet = false
    @State private var showSettings = false
    @State private var showStatistics = false
    @State private var showOCRSheet = false
    @State private var searchText = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.clipboardItems
        
        // Kategori filtrelemesi
        if clipboardManager.selectedCategory != .all {
            if clipboardManager.selectedCategory == .pinned {
                items = items.filter { $0.isPinned }
            } else if clipboardManager.selectedCategory == .favorite {
                items = items.filter { $0.isFavorite }
            } else {
                items = items.filter { $0.category == clipboardManager.selectedCategory }
            }
        }
        
        // Arama filtrelemesi
        if !searchText.isEmpty {
            items = items.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            let pinnedItems = items.filter { $0.isPinned }
            let unpinnedItems = items.filter { !$0.isPinned }
            items = pinnedItems + unpinnedItems
        }
        
        return items
    }
    
    var body: some View {
        Group {
            if !onboardingManager.isOnboardingCompleted {
                OnboardingView(onboardingManager: onboardingManager)
            } else {
                mainContentView
            }
        }
        .onAppear {
            setupNotificationObserver()
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutView(showAboutSheet: $showAboutSheet)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(showSettings: $showSettings)
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(showStatistics: $showStatistics)
        }
        .sheet(isPresented: $showOCRSheet) {
            ImageOCRView(isPresented: $showOCRSheet)
        }
    }
    
    private var mainContentView: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    if !clipboardManager.clipboardItems.isEmpty {
                        HeaderSectionView(
                            clipboardManager: clipboardManager,
                            searchText: $searchText
                        )
                    }
                    
                    ContentSectionView(
                        clipboardManager: clipboardManager,
                        filteredItems: filteredItems,
                        searchText: searchText,
                        showToastMessage: showToastMessage,
                        onDeleteItem: deleteItem,
                        onTogglePin: togglePin
                    )
                    
                    if showToast {
                        ToastView(message: toastMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .offset(y: 10)
                    }
                }
            }
            .navigationTitle("Pano Geçmişi")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !clipboardManager.clipboardItems.isEmpty {
                        Button(action: {
                            withAnimation(.spring()) {
                                clearAllItems()
                                searchText = ""
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    
                    Button(action: { 
                        HapticManager.trigger(.light)
                        showStatistics = true 
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Button(action: { 
                        HapticManager.trigger(.light)
                        showSettings = true 
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                    
                    Menu {
                        Button(action: {
                            UserDefaults.standard.removeObject(forKey: "isOnboardingCompleted")
                            onboardingManager.isOnboardingCompleted = false
                        }) {
                            Label("Kurulum Sihirbazı", systemImage: "wand.and.stars")
                        }
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("Klavye Ayarları", systemImage: "keyboard")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showOCRSheet = true
                        }) {
                            Label("Görselden Metin", systemImage: "text.viewfinder")
                        }
                        
                        Button(action: {
                            showAboutSheet = true
                        }) {
                            Label("Hakkında", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

// MARK: - ContentView Helper Functions
extension ContentView {
    
    func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .clipboardManagerDataChanged,
            object: nil,
            queue: .main
        ) { _ in
            clipboardManager.loadItems()
        }
    }
    
    func showToastMessage(_ message: String) {
        withAnimation {
            self.toastMessage = message
            self.showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showToast = false
            }
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showToastMessage("Öğe silindi")
    }
    
    func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showToastMessage(item.isPinned ? "Sabitleme kaldırıldı" : "Sabitlendi")
    }
    
    func clearAllItems() {
        clipboardManager.clearAllItems()
    }
}

// MARK: - Image OCR View (inline)
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
                
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Kamera ile Çek", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
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
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        Task { await handleImageData(data) }
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task { await handleSelection(item: newItem) }
            }
        }
    }
    
    @State private var isShowingCamera = false
    
    @MainActor
    private func handleSelection(item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Görsel okunamadı"
                return
            }
            await handleImageData(data)
            return
        } catch {
            errorMessage = "OCR başarısız: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func handleImageData(_ data: Data) async {
        do {
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

// MARK: - Camera Picker
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { onImage(img) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}
