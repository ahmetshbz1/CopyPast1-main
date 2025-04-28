import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager.shared
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showSettings = false
    @State private var showAboutSheet = false
    @State private var animateBackground = false
    @State private var searchText = ""
    @Environment(\.colorScheme) private var colorScheme

    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.clipboardItems

        // Önce kategori filtrelemesi yap
        if clipboardManager.selectedCategory != .all {
            if clipboardManager.selectedCategory == .pinned {
                items = items.filter { $0.isPinned }
        } else {
                items = items.filter { $0.category == clipboardManager.selectedCategory }
            }
        }

        // Sonra arama filtrelemesi yap
        if !searchText.isEmpty {
            items = items.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            // Arama yoksa, sabitleri en üste getir
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
                NavigationView {
                    ZStack {
                        // Animasyonlu arka plan
                        GeometryReader { geometry in
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.08))
                                    .frame(width: geometry.size.width * 0.6)
                                    .offset(x: animateBackground ? geometry.size.width * 0.3 : -geometry.size.width * 0.3,
                                            y: animateBackground ? geometry.size.height * 0.2 : -geometry.size.height * 0.2)
                                    .blur(radius: 60)

                                Circle()
                                    .fill(Color.purple.opacity(0.08))
                                    .frame(width: geometry.size.width * 0.8)
                                    .offset(x: animateBackground ? -geometry.size.width * 0.2 : geometry.size.width * 0.2,
                                            y: animateBackground ? -geometry.size.height * 0.3 : geometry.size.height * 0.3)
                                    .blur(radius: 60)
                            }
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                                    animateBackground.toggle()
                                }
                            }
                        }
                        .ignoresSafeArea()

                        VStack(spacing: 0) {
                            if !clipboardManager.clipboardItems.isEmpty {
                                VStack(spacing: 8) {
                                // Arama alanı
                                SearchBar(text: $searchText)
                                    .padding(.horizontal)
                                    .padding(.top, 10)

                                    // Kategori filtreleme çubuğu
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(ItemCategory.allCases, id: \.self) { category in
                                                CategoryButton(
                                                    category: category,
                                                    isSelected: clipboardManager.selectedCategory == category,
                                                    onTap: {
                                                        withAnimation {
                                                            clipboardManager.selectedCategory = category
                                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                                            generator.impactOccurred()
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }

                            if clipboardManager.clipboardItems.isEmpty {
                                // Boş durum görünümü
                                VStack(spacing: 24) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 70))
                                        .foregroundColor(.blue.opacity(0.6))
                                        .padding(.bottom, 10)
                                        .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)

                                    Text("Henüz Kopyalanan Metin Yok")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)

                                    Text("Herhangi bir metni kopyaladığınızda\notomatik olarak burada listelenecek")
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)

                                    Spacer()
                                }
                                .padding(.top, 60)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                if filteredItems.isEmpty {
                                    // Filtreleme sonuçları boş görünümü
                                    VStack(spacing: 24) {
                                        if !searchText.isEmpty {
                                    // Arama sonucu boş durumu
                                        Image(systemName: "magnifyingglass")
                                                .font(.system(size: 50))
                                            .foregroundColor(.gray)

                                        Text("Sonuç Bulunamadı")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.primary)

                                        Text("\"\(searchText)\" ile eşleşen bir sonuç yok")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                        } else {
                                            // Kategori filtrelemesi boş durumu
                                            Image(systemName: clipboardManager.selectedCategory.icon)
                                                .font(.system(size: 50))
                                                .foregroundColor(clipboardManager.selectedCategory.color.opacity(0.6))
                                                .shadow(color: clipboardManager.selectedCategory.color.opacity(0.1), radius: 10, x: 0, y: 5)

                                            Text("Bu Kategoride Öğe Yok")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.primary)

                                            Text("\(clipboardManager.selectedCategory.rawValue) kategorisinde henüz öğe bulunmuyor")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    .padding(.top, 60)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    // Kopyalanan metinler listesi
                                    List {
                                        ForEach(filteredItems) { item in
                                            ClipboardItemView(
                                                item: item,
                                                showToastMessage: showToastMessage
                                            )
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    withAnimation {
                                                        deleteItem(item)
                                                    }
                                                } label: {
                                                    Label("Sil", systemImage: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                                Button {
                                                    withAnimation {
                                                        togglePin(item)
                                                    }
                                                } label: {
                                                    Label(item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                                                          systemImage: item.isPinned ? "pin.slash" : "pin")
                                                }
                                                .tint(.blue)
                                            }
                                        }
                                    }
                                    .listStyle(.plain)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .refreshable {
                                        clipboardManager.loadItems()
                                    }
                                }
                            }

                            // Toast mesajı
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
                                        clipboardManager.clipboardItems.removeAll()
                                        clipboardManager.userDefaults?.removeObject(forKey: "clipboardItems")
                                        searchText = "" // Temizleme işleminde arama metnini de sıfırla
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .buttonStyle(ToolbarButtonStyle())
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

                                Button(action: {
                                    if let url = URL(string: UIApplication.openSettingsURLString + "/ClipboardManager") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Label("Arka Plan Yenileme", systemImage: "arrow.clockwise")
                                }

                                Divider()

                                Button(action: {
                                    showAboutSheet = true
                                }) {
                                    Label("Hakkında", systemImage: "info.circle")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .buttonStyle(ToolbarButtonStyle())
                        }
                    }
                }
            }
        }
        .onAppear {
            // ClipboardManager değişikliklerini dinle
            NotificationCenter.default.addObserver(
                forName: ClipboardManager.clipboardChangedNotification,
                object: nil,
                queue: .main
            ) { _ in
                clipboardManager.loadItems()
            }
        }
        .sheet(isPresented: $showAboutSheet) {
            NavigationView {
                List {
                    Section {
                        VStack(spacing: 16) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .cornerRadius(20)
                                .shadow(color: .blue.opacity(0.2), radius: 10)

                            Text("Pano Yöneticisi")
                                .font(.title2.bold())

                            Text("Sürüm 1.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Geliştirici")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Ahmet")
                                .font(.body)
                        }
                        .padding(.vertical, 4)

                        Link(destination: URL(string: "https://github.com/AhmetShbz")!) {
                            HStack {
                                Image(systemName: "link")
                                Text("GitHub")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.footnote)
                            }
                        }

                        Link(destination: URL(string: "https://www.buymeacoffee.com/ahmetknkc")!) {
                            HStack {
                                Image(systemName: "cup.and.saucer")
                                Text("Bana Kahve Ismarla")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.footnote)
                            }
                        }
                    } header: {
                        Text("İletişim")
                    }

                    Section {
                        Text("Bu uygulama, kopyaladığınız metinleri güvenli bir şekilde saklar ve istediğiniz zaman erişmenizi sağlar. Tüm verileriniz yalnızca sizin cihazınızda tutulur ve üçüncü taraflarla paylaşılmaz.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Hakkında")
                    }
                }
                .navigationTitle("Hakkında")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Tamam") {
                            showAboutSheet = false
                        }
                    }
                }
            }
        }
    }

    private func showToastMessage(_ message: String) {
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

    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.deleteItem(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showToastMessage("Öğe silindi")
    }

    private func togglePin(_ item: ClipboardItem) {
        clipboardManager.togglePinItem(item)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showToastMessage(item.isPinned ? "Sabitlendi" : "Sabitleme kaldırıldı")
    }
}

// Kategori buton görünümü
struct CategoryButton: View {
    let category: ItemCategory
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 13))

                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? category.color
                          : (colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.8)))
                    .shadow(color: isSelected ? category.color.opacity(0.3) : Color.black.opacity(0.04),
                            radius: isSelected ? 4 : 1,
                            x: 0,
                            y: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Metinlerde Ara...", text: $text)
                .font(.system(size: 16))
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: {
                    withAnimation {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.15) : Color.white.opacity(0.5))
                .background(.ultraThinMaterial)
                .cornerRadius(12)
        )
    }
}

struct ToastView: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

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
            showToastMessage("Kopyalandı")
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 16))
                        .foregroundColor(item.category.color.opacity(0.8))

                    Text(item.category.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(timeAgoDisplay(date: item.date))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text(item.text)
                    .lineLimit(2)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.15) : Color.white.opacity(0.5))
                    .background(.ultraThinMaterial)
            )
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .overlay(
                item.isPinned ?
                    RoundedRectangle(cornerRadius: 14)
                    .stroke(ItemCategory.pinned.color.opacity(0.5), lineWidth: 1.5)
                    : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: {
                withAnimation {
                    togglePin(item)
                }
            }) {
                Label(item.isPinned ? "Sabitlemeyi Kaldır" : "Sabitle",
                      systemImage: item.isPinned ? "pin.slash" : "pin")
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

            Button(action: {
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
            }) {
                Label("Paylaş", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showEditSheet) {
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
                            if let index = clipboardManager.clipboardItems.firstIndex(where: { $0.id == item.id }) {
                                clipboardManager.clipboardItems[index].text = editedText
                                clipboardManager.saveItems()
                            }
                            showEditSheet = false
                        }
                    }
                }
            }
        }
    }

    private func togglePin(_ item: ClipboardItem) {
        if let index = clipboardManager.clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardManager.clipboardItems[index].isPinned.toggle()
            clipboardManager.saveItems()
        }
    }

    private func deleteItem(_ item: ClipboardItem) {
        clipboardManager.clipboardItems.removeAll(where: { $0.id == item.id })
        clipboardManager.saveItems()
    }
}

// Zaman gösterimi fonksiyonu
func timeAgoDisplay(date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

    if let day = components.day, day > 0 {
        return "\(day)g önce"
    } else if let hour = components.hour, hour > 0 {
        return "\(hour)s önce"
    } else if let minute = components.minute, minute > 0 {
        return "\(minute)d önce"
    } else {
        return "Şimdi"
    }
}

struct ClipboardItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
