import UIKit
import CoreImage.CIFilterBuiltins

public struct QRCodeGenerator {
    private static let context = CIContext()
    private static let filter = CIFilter.qrCodeGenerator()
    
    /// QR kod oluşturur
    public static func generateQRCode(from text: String, size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale'i ayarla
        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// QR kodu bitmap'e çevirir (daha net)
    public static func generateHighResolutionQRCode(from text: String) -> UIImage? {
        return generateQRCode(from: text, size: CGSize(width: 1024, height: 1024))
    }
}
