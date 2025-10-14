import SwiftUI

struct EditItemSheet: View {
    let item: ClipboardItem
    @Binding var editedText: String
    @Binding var showEditSheet: Bool
    @StateObject private var clipboardManager = ClipboardManager.shared
    
    @State private var currentNote: String = ""
    @State private var currentTags: [String] = []
    @State private var newTag: String = ""
    @State private var showTagInput: Bool = false
    @State private var showNoteEditor: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // İstatistikler
                    statsView
                    
                    // Düzenleyici
                    TextEditor(text: $editedText)
                        .padding(8)
                        .frame(minHeight: 150, maxHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Dönüşüm araçları
                    transformToolbar
                    
                    Divider()
                    
                    // Etiketler bölümü
                    tagsSection
                    
                    // Not bölümü
                    noteSection
                }
                .padding()
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
        .onAppear {
            currentNote = item.note ?? ""
            currentTags = item.tags
        }
    }
    
    private var statsView: some View {
        HStack(spacing: 12) {
            Label("\(editedText.count) karakter", systemImage: "textformat")
                .font(.footnote)
                .foregroundColor(.secondary)
            Divider()
            Label("\(editedText.wordCount) kelime", systemImage: "character.cursor.ibeam")
                .font(.footnote)
                .foregroundColor(.secondary)
            Divider()
            Label("\(editedText.lineCount) satır", systemImage: "text.justify")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var transformToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button("Trim") { editedText = editedText.trimmed() }
                Button("Upper") { editedText = editedText.uppercasedTr() }
                Button("Lower") { editedText = editedText.lowercasedTr() }
                Button("Capitalize") { editedText = editedText.capitalizedTr() }
                Button("Tek Satır") { editedText = editedText.singleLined() }
                Button("Dup Sil") { editedText = editedText.removingDuplicateLines() }
            }
            .buttonStyle(.bordered)
            .font(.footnote)
            .padding(.horizontal)
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Etiketler", systemImage: "tag.fill")
                    .font(.headline)
                Spacer()
                Button(action: { showTagInput.toggle() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            if showTagInput {
                HStack {
                    TextField("Yeni etiket", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    
                    Button("Ekle") {
                        addTag()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTag.trimmed().isEmpty)
                }
            }
            
            if !currentTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(currentTags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.subheadline)
                            Button(action: { removeTag(tag) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                    }
                }
            } else {
                Text("Henüz etiket eklenmemiş")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Not", systemImage: "note.text")
                    .font(.headline)
                Spacer()
                Button(showNoteEditor ? "Gizle" : "Düzenle") {
                    showNoteEditor.toggle()
                }
                .font(.caption)
            }
            
            if showNoteEditor {
                TextEditor(text: $currentNote)
                    .frame(height: 80)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            } else if !currentNote.isEmpty {
                Text(currentNote)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
            } else {
                Text("Henüz not eklenmemiş")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmed()
        if !trimmedTag.isEmpty && !currentTags.contains(trimmedTag) {
            currentTags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        currentTags.removeAll { $0 == tag }
    }
    
    private func saveEditedItem() {
        if let index = clipboardManager.clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardManager.clipboardItems[index].text = editedText
            clipboardManager.clipboardItems[index].tags = currentTags
            clipboardManager.clipboardItems[index].note = currentNote.isEmpty ? nil : currentNote
            clipboardManager.saveItems()
        }
        showEditSheet = false
    }
}

// MARK: - FlowLayout Helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
