import SwiftUI

struct QRCodeView: View {
    let text: String
    @Binding var showQRCode: Bool
    @State private var qrImage: UIImage?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 10)
                        )
                } else {
                    ProgressView("QR Kod oluşturuluyor...")
                }
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal)
                
                Button(action: shareQRCode) {
                    Label("QR Kodu Paylaş", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(qrImage == nil)
            }
            .padding()
            .navigationTitle("QR Kod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        showQRCode = false
                    }
                }
            }
        }
        .onAppear {
            generateQRCode()
        }
    }
    
    private func generateQRCode() {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = QRCodeGenerator.generateHighResolutionQRCode(from: text)
            DispatchQueue.main.async {
                self.qrImage = image
                if image != nil {
                    HapticManager.trigger(.success)
                }
            }
        }
    }
    
    private func shareQRCode() {
        guard let image = qrImage else { return }
        
        HapticManager.trigger(.light)
        
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // iPad için popover ayarı
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            // En üstteki view controller'i bul
            var topController = window.rootViewController
            while let presented = topController?.presentedViewController {
                topController = presented
            }
            
            topController?.present(activityVC, animated: true)
        }
    }
}
