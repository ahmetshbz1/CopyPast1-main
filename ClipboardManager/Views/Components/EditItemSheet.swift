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
    @FocusState private var focusedField: Field?
    @StateObject private var keyboard = KeyboardObserver()
    
    enum Field: Hashable {
        case tagInput
        case noteEditor
    }
    
    var body: some View {
        NavigationView {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                    // İstatistikler
                    statsView
                        .padding(.horizontal)
                    
                    // Düzenleyici
                    textEditorSection
                        .padding(.horizontal)
                    
                    // Dönüşüm araçları
                    transformToolbar
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Etiketler bölümü
                    tagsSection
                        .padding(.horizontal)
                    
                    // Not bölümü
                    noteSection
                        .padding(.horizontal)
                    
                        Spacer(minLength: 20)
                    }
                    .padding(.vertical)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: keyboard.keyboardHeight)
                }
                .onChange(of: focusedField) { newValue in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let field = newValue {
                            scrollProxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
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
                .frame(height: 12)
            Label("\(editedText.wordCount) kelime", systemImage: "character.cursor.ibeam")
                .font(.footnote)
                .foregroundColor(.secondary)
            Divider()
                .frame(height: 12)
            Label("\(editedText.lineCount) satır", systemImage: "text.justify")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metin İçeriği")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                TextEditor(text: $editedText)
                    .padding(8)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .frame(height: 150)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Etiketler")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { 
                    withAnimation(.spring(response: 0.3)) {
                        showTagInput.toggle()
                    }
                }) {
                    Label(showTagInput ? "İptal" : "Ekle", systemImage: showTagInput ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if showTagInput {
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Etiket adı girin...", text: $newTag, onCommit: addTag)
                        .font(.system(size: 16))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .tagInput)
                    
                    if !newTag.isEmpty {
                        Button(action: { newTag = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: addTag) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                        )
                )
                .transition(.scale.combined(with: .opacity))
                .id(Field.tagInput)
                .onAppear {
                    if showTagInput {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .tagInput
                        }
                    }
                }
            }
            
            if !currentTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(currentTags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Button(action: { 
                                withAnimation(.spring(response: 0.3)) {
                                    removeTag(tag)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue)
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            } else if !showTagInput {
                HStack {
                    Image(systemName: "tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Etiket eklemek için + butonuna dokunun")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Not")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showNoteEditor.toggle()
                    }
                }) {
                    Label(showNoteEditor ? "Kapat" : "Düzenle", systemImage: showNoteEditor ? "chevron.up.circle.fill" : "pencil.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            
            if showNoteEditor {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
                            )
                        
                        TextEditor(text: $currentNote)
                            .padding(12)
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .font(.system(size: 15))
                            .focused($focusedField, equals: .noteEditor)
                        
                        if currentNote.isEmpty {
                            Text("Notunuzu buraya yazın...")
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 100)
                }
                .id(Field.noteEditor)
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    if showNoteEditor {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .noteEditor
                        }
                    }
                }
            } else if !currentNote.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    
                    Text(currentNote)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            } else if !showNoteEditor {
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Not eklemek için düzenle butonuna dokunun")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
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
