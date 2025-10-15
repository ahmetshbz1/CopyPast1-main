import SwiftUI

import Security

private let aiKeyServiceName = "com.ahmtcanx.clipboardmanager"
private let aiKeyAccount = "openai_api_key"

struct AISettingsSection: View {
    @State private var apiKey: String = ""
    @State private var showSaved = false
    @State private var showCleared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("OpenAI API Key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 14))
            
            HStack {
                Button {
                    do {
                        try setKey(apiKey)
                        showSaved = true
                    } catch {
                        showSaved = false
                    }
                } label: {
                    Label("Kaydet", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                
                Button(role: .destructive) {
                    do {
                        try removeKey()
                        apiKey = ""
                        showCleared = true
                    } catch {
                        showCleared = false
                    }
                } label: {
                    Label("Temizle", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            
            if showSaved {
                Text("API anahtarı kaydedildi")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            if showCleared {
                Text("API anahtarı silindi")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .onAppear {
            if let key = try? getKey() {
                apiKey = key ?? ""
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Keychain helpers (local)
private func setKey(_ value: String) throws {
    let data = Data(value.utf8)
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: aiKeyServiceName,
        kSecAttrAccount as String: aiKeyAccount
    ]
    SecItemDelete(query as CFDictionary)
    var attrs = query
    attrs[kSecValueData as String] = data
    let status = SecItemAdd(attrs as CFDictionary, nil)
    guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
}

private func getKey() throws -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: aiKeyServiceName,
        kSecAttrAccount as String: aiKeyAccount,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var res: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &res)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    guard let data = res as? Data, let str = String(data: data, encoding: .utf8) else { return nil }
    return str
}

private func removeKey() throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: aiKeyServiceName,
        kSecAttrAccount as String: aiKeyAccount
    ]
    SecItemDelete(query as CFDictionary)
}
