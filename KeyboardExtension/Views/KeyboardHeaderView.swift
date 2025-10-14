import SwiftUI

struct KeyboardHeaderView: View {
    let onDismiss: () -> Void
    let onReturn: () -> Void
    let onDelete: () -> Void
    let onDeleteLongPress: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var deleteTimer: Timer?
    
    var body: some View {
        HStack {
            dismissButton
            Spacer()
            returnButton
            deleteButton
        }
    }
    
    private var dismissButton: some View {
        Button(action: {
            onDismiss()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 17))
                Text("Klavye")
                    .font(.system(size: 15))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .padding(.leading, 12)
        .padding(.vertical, 8)
    }
    
    private var returnButton: some View {
        Button(action: {
            onReturn()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "return")
                    .font(.system(size: 17))
                Text("Satır")
                    .font(.system(size: 15))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .padding(.trailing, 6)
    }
    
    private var deleteButton: some View {
        Button(action: {
            if deleteTimer == nil {
                onDelete()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "delete.left")
                    .font(.system(size: 17))
                Text("Sil")
                    .font(.system(size: 15))
            }
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    deleteTimer?.invalidate()
                    deleteTimer = nil
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDeleteLongPress()
                    
                    deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        onDelete()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
        )
        .padding(.trailing, 12)
    }
}