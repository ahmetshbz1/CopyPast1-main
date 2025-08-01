import SwiftUI

struct KeyboardClipboardItemView: View {
    let item: ClipboardItem
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            ItemContentView(item: item, colorScheme: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
    }
}