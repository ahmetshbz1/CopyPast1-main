import Foundation
import LocalAuthentication
import CryptoKit

public protocol SecurityManagerProtocol {
    func authenticateUser() async throws -> Bool
    func encryptData(_ data: Data) throws -> Data
    func decryptData(_ encryptedData: Data) throws -> Data
    func generateSecureKey() -> SymmetricKey
    func isDeviceSecure() -> Bool
    func canUseBiometrics() -> Bool
}

public enum SecurityError: LocalizedError {
    case biometricNotAvailable
    case biometricNotEnrolled
    case authenticationFailed
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    case deviceNotSecure
    
    public var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometrik kimlik doğrulama kullanılamıyor"
        case .biometricNotEnrolled:
            return "Biometrik kimlik doğrulama ayarlanmamış"
        case .authenticationFailed:
            return "Kimlik doğrulama başarısız"
        case .encryptionFailed:
            return "Şifreleme başarısız"
        case .decryptionFailed:
            return "Şifre çözme başarısız"
        case .keyGenerationFailed:
            return "Anahtar oluşturma başarısız"
        case .deviceNotSecure:
            return "Cihaz güvenli değil"
        }
    }
}

public enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    public var displayName: String {
        switch self {
        case .none: return "Biometrik yok"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }
}

public class SecurityManager: SecurityManagerProtocol {
    
    private let context = LAContext()
    private let keychain = KeychainManager()
    
    public init() {}
    
    public func authenticateUser() async throws -> Bool {
        let context = LAContext()
        
        // Biometric kullanılabilirlik kontrolü
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    throw SecurityError.biometricNotAvailable
                case LAError.biometryNotEnrolled.rawValue:
                    throw SecurityError.biometricNotEnrolled
                default:
                    throw SecurityError.authenticationFailed
                }
            }
            throw SecurityError.biometricNotAvailable
        }
        
        // Biometric authentication
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Pano verilerinize erişmek için kimliğinizi doğrulayın"
            )
            return result
        } catch {
            throw SecurityError.authenticationFailed
        }
    }
    
    public func encryptData(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined!
        } catch {
            throw SecurityError.encryptionFailed
        }
    }
    
    public func decryptData(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SecurityError.decryptionFailed
        }
    }
    
    public func generateSecureKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    public func isDeviceSecure() -> Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
    
    public func canUseBiometrics() -> Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    public func getBiometricType() -> BiometricType {
        guard canUseBiometrics() else { return .none }
        
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }
    
    // Private helper methods
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        let keyIdentifier = "com.ahmtcanx.clipboardmanager.encryption.key"
        
        // Önce keychain'den anahtarı al
        if let keyData = keychain.retrieve(identifier: keyIdentifier) {
            return SymmetricKey(data: keyData)
        }
        
        // Anahtar yoksa yeni oluştur
        let newKey = generateSecureKey()
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        guard keychain.store(data: keyData, identifier: keyIdentifier) else {
            throw SecurityError.keyGenerationFailed
        }
        
        return newKey
    }
}

// Keychain wrapper
public class KeychainManager {
    
    public func store(data: Data, identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Önce varolan kaydı sil
        SecItemDelete(query as CFDictionary)
        
        // Yeni kaydı ekle
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func retrieve(identifier: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    public func delete(identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// Privacy manager
public class PrivacyManager: ObservableObject {
    
    @Published public var isPrivacyModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPrivacyModeEnabled, forKey: "privacyMode")
        }
    }
    
    @Published public var autoDeleteSensitiveContent: Bool {
        didSet {
            UserDefaults.standard.set(autoDeleteSensitiveContent, forKey: "autoDeleteSensitive")
        }
    }
    
    @Published public var requireAuthenticationForSensitiveContent: Bool {
        didSet {
            UserDefaults.standard.set(requireAuthenticationForSensitiveContent, forKey: "authForSensitive")
        }
    }
    
    public init() {
        self.isPrivacyModeEnabled = UserDefaults.standard.bool(forKey: "privacyMode")
        self.autoDeleteSensitiveContent = UserDefaults.standard.bool(forKey: "autoDeleteSensitive")
        self.requireAuthenticationForSensitiveContent = UserDefaults.standard.bool(forKey: "authForSensitive")
    }
    
    public func isSensitiveContent(_ text: String) -> Bool {
        let patterns = [
            // Kredi kartı numaraları
            "\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b",
            // Sosyal güvenlik numaraları
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            // E-posta adresleri
            "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            // Telefon numaraları
            "\\b(?:\\+?1[-.]?)?\\(?\\d{3}\\)?[-.]?\\d{3}[-.]?\\d{4}\\b",
            // Şifre benzeri pattern
            "(?i)password|şifre|parola"
        ]
        
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    public func maskSensitiveContent(_ text: String) -> String {
        guard isPrivacyModeEnabled else { return text }
        
        var maskedText = text
        
        // E-posta maskele
        maskedText = maskedText.replacingOccurrences(
            of: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            with: "***@***.***",
            options: .regularExpression
        )
        
        // Kredi kartı maskele
        maskedText = maskedText.replacingOccurrences(
            of: "\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b",
            with: "**** **** **** ****",
            options: .regularExpression
        )
        
        return maskedText
    }
}