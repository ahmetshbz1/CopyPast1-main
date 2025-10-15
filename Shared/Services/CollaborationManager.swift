import Foundation
import Network
import MultipeerConnectivity
import UIKit
import UserNotifications

// UIDevice.current.name için Swift 6 uyumluluğu
fileprivate extension UIDevice {
    @MainActor
    var deviceName: String {
        self.name
    }
    
    // Non-async context'te kullanım için
    var safeDeviceName: String {
        if #available(iOS 16.0, *) {
            return MainActor.assumeIsolated { self.name }
        } else {
            return self.name
        }
    }
}

public protocol CollaborationManagerProtocol {
    func createShareableLink(for item: EnhancedClipboardItem, expirationTime: TimeInterval?) async throws -> URL
    func shareWithQRCode(item: EnhancedClipboardItem) throws -> Data
    func startLocalNetworkSharing() throws
    func stopLocalNetworkSharing()
    func shareToTeamChannel(_ item: EnhancedClipboardItem, channelId: String) async throws
}

public enum CollaborationError: LocalizedError {
    case sharingNotAvailable
    case linkGenerationFailed
    case qrCodeGenerationFailed
    case networkError(Error)
    case authenticationRequired
    case permissionDenied
    case itemNotFound
    case channelNotFound
    
    public var errorDescription: String? {
        switch self {
        case .sharingNotAvailable:
            return "Paylaşım özelliği kullanılamıyor"
        case .linkGenerationFailed:
            return "Paylaşım linki oluşturulamadı"
        case .qrCodeGenerationFailed:
            return "QR kod oluşturulamadı"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        case .authenticationRequired:
            return "Kimlik doğrulama gerekli"
        case .permissionDenied:
            return "İzin reddedildi"
        case .itemNotFound:
            return "Öğe bulunamadı"
        case .channelNotFound:
            return "Kanal bulunamadı"
        }
    }
}

// Sharing Manager
public class CollaborationManager: NSObject, CollaborationManagerProtocol, ObservableObject {
    
    @Published public var nearbyDevices: [Device] = []
    @Published public var isSharing: Bool = false
    @Published public var teamChannels: [TeamChannel] = []
    
    private let securityManager = SecurityManager()
    private var mcSession: MCSession?
    private var mcAdvertiserAssistant: MCAdvertiserAssistant?
    private var mcBrowserViewController: MCBrowserViewController?
    
    private let serviceType = "clipboard-share"
    private let peerID: MCPeerID
    
    public override init() {
        self.peerID = MCPeerID(displayName: UIDevice.current.safeDeviceName)
        super.init()
        loadTeamChannels()
    }
    
    public func createShareableLink(for item: EnhancedClipboardItem, expirationTime: TimeInterval? = 3600) async throws -> URL {
        // Temporary sharing service - production'da gerçek bir backend olacak
        let shareableItem = ShareableItem(
            id: UUID(),
            originalItemId: item.id,
            content: item.textContent ?? "",
            title: item.title,
            mediaType: item.mediaType,
            createdDate: Date(),
            expirationDate: expirationTime != nil ? Date().addingTimeInterval(expirationTime!) : nil,
            accessCount: 0,
            maxAccess: 10
        )
        
        // Encrypt content for security
        let encryptedContent = try securityManager.encryptData(shareableItem.content.data(using: .utf8) ?? Data())
        let shareId = shareableItem.id.uuidString
        
        // Store in temporary storage (production'da server'da tutulacak)
        UserDefaults.standard.set(encryptedContent, forKey: "share_\(shareId)")
        UserDefaults.standard.set(try JSONEncoder().encode(shareableItem), forKey: "shareInfo_\(shareId)")
        
        // Generate shareable URL
        let baseURL = "https://clipboard.ahmtcanx.com/share/"
        guard let url = URL(string: "\(baseURL)\(shareId)") else {
            throw CollaborationError.linkGenerationFailed
        }
        
        return url
    }
    
    public func shareWithQRCode(item: EnhancedClipboardItem) throws -> Data {
        // QR kodu için veri hazırla
        let qrData = QRShareData(
            title: item.title,
            content: item.textContent ?? "",
            mediaType: item.mediaType.rawValue,
            timestamp: Date().timeIntervalSince1970
        )
        
        guard let jsonData = try? JSONEncoder().encode(qrData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw CollaborationError.qrCodeGenerationFailed
        }
        
        // Statik fonksiyonu tip üzerinden çağır ve UIImage'ı Data'ya dönüştür
        guard let image = QRCodeGenerator.generateHighResolutionQRCode(from: jsonString) ?? QRCodeGenerator.generateQRCode(from: jsonString),
              let data = image.pngData() else {
            throw CollaborationError.qrCodeGenerationFailed
        }
        
        return data
    }
    
    public func startLocalNetworkSharing() throws {
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
        
        mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: serviceType, discoveryInfo: nil, session: mcSession!)
        mcAdvertiserAssistant?.start()
        
        isSharing = true
    }
    
    public func stopLocalNetworkSharing() {
        mcAdvertiserAssistant?.stop()
        mcSession?.disconnect()
        mcAdvertiserAssistant = nil
        mcSession = nil
        
        isSharing = false
        nearbyDevices.removeAll()
    }
    
    public func shareToTeamChannel(_ item: EnhancedClipboardItem, channelId: String) async throws {
        guard let channel = teamChannels.first(where: { $0.id.uuidString == channelId }) else {
            throw CollaborationError.channelNotFound
        }
        
        let deviceName = await UIDevice.current.deviceName
        let sharedItem = SharedChannelItem(
            id: UUID(),
            originalItemId: item.id,
            content: item.textContent ?? "",
            title: item.title,
            mediaType: item.mediaType,
            sharedBy: deviceName,
            sharedDate: Date(),
            channelId: channel.id
        )
        
        // Simulate network call - production'da gerçek API çağrısı
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Add to channel locally (production'da server'dan sync edilecek)
        if let index = teamChannels.firstIndex(where: { $0.id == channel.id }) {
            teamChannels[index].items.append(sharedItem)
            saveTeamChannels()
        }
    }
    
    public func sendToNearbyDevice(_ item: EnhancedClipboardItem, device: Device) async throws {
        guard let session = mcSession,
              let peer = device.peer else {
            throw CollaborationError.sharingNotAvailable
        }
        
        let deviceName = await UIDevice.current.deviceName
        let shareData = NearbyShareData(
            title: item.title,
            content: item.textContent ?? "",
            mediaType: item.mediaType.rawValue,
            senderName: deviceName
        )
        
        let data = try JSONEncoder().encode(shareData)
        
        try session.send(data, toPeers: [peer], with: .reliable)
    }
    
    public func createTeamChannel(name: String, description: String) -> TeamChannel {
        let deviceName = UIDevice.current.safeDeviceName
        let channel = TeamChannel(
            name: name,
            description: description,
            createdBy: deviceName,
            members: [deviceName]
        )
        
        teamChannels.append(channel)
        saveTeamChannels()
        
        return channel
    }
    
    public func joinTeamChannel(inviteCode: String) async throws {
        // Simulate invite code validation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        guard inviteCode.count == 8 else {
            throw CollaborationError.authenticationRequired
        }
        
        let deviceName = await UIDevice.current.deviceName
        let channel = TeamChannel(
            name: "Paylaşılan Kanal",
            description: "Davet kodu ile katılınan kanal",
            createdBy: "Diğer Kullanıcı",
            members: ["Diğer Kullanıcı", deviceName]
        )
        
        teamChannels.append(channel)
        saveTeamChannels()
    }
    
    public func generateInviteCode(for channel: TeamChannel) -> String {
        // Basit invite code generation
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
    
    // Private methods
    private func loadTeamChannels() {
        if let data = UserDefaults.standard.data(forKey: "teamChannels"),
           let channels = try? JSONDecoder().decode([TeamChannel].self, from: data) {
            teamChannels = channels
        }
    }
    
    private func saveTeamChannels() {
        if let data = try? JSONEncoder().encode(teamChannels) {
            UserDefaults.standard.set(data, forKey: "teamChannels")
        }
    }
}

// MARK: - MCSessionDelegate
extension CollaborationManager: MCSessionDelegate {
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                let device = Device(name: peerID.displayName, peer: peerID, status: .connected)
                if !self.nearbyDevices.contains(where: { $0.peer?.displayName == peerID.displayName }) {
                    self.nearbyDevices.append(device)
                }
            case .notConnected:
                self.nearbyDevices.removeAll { $0.peer?.displayName == peerID.displayName }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let shareData = try? JSONDecoder().decode(NearbyShareData.self, from: data) {
            DispatchQueue.main.async {
                self.handleIncomingShare(shareData)
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    private func handleIncomingShare(_ shareData: NearbyShareData) {
        _ = ClipboardItem(text: shareData.content)
        ClipboardManager.shared.addItem(shareData.content)
        ClipboardManager.shared.saveItems()
        
        // Notification göster
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Yeni Paylaşım"
        content.body = "\(shareData.senderName) sizinle bir öğe paylaştı"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        center.add(request)
    }
}

// MARK: - Models
public struct ShareableItem: Codable {
    public let id: UUID
    public let originalItemId: UUID
    public let content: String
    public let title: String
    public let mediaType: MediaType
    public let createdDate: Date
    public let expirationDate: Date?
    public var accessCount: Int
    public let maxAccess: Int
}

public struct QRShareData: Codable {
    public let title: String
    public let content: String
    public let mediaType: String
    public let timestamp: TimeInterval
}

public struct NearbyShareData: Codable {
    public let title: String
    public let content: String
    public let mediaType: String
    public let senderName: String
}

public struct Device: Identifiable {
    public let id = UUID()
    public let name: String
    public let peer: MCPeerID?
    public let status: DeviceStatus
    
    public enum DeviceStatus {
        case connected
        case connecting
        case disconnected
        
        public var displayName: String {
            switch self {
            case .connected: return "Bağlı"
            case .connecting: return "Bağlanıyor"
            case .disconnected: return "Bağlı Değil"
            }
        }
    }
}

public struct TeamChannel: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let description: String
    public let createdDate: Date
    public let createdBy: String
    public var members: [String]
    public var items: [SharedChannelItem]
    
    public init(name: String, description: String, createdBy: String, members: [String]) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.createdDate = Date()
        self.createdBy = createdBy
        self.members = members
        self.items = []
    }
}

public struct SharedChannelItem: Identifiable, Codable {
    public let id: UUID
    public let originalItemId: UUID
    public let content: String
    public let title: String
    public let mediaType: MediaType
    public let sharedBy: String
    public let sharedDate: Date
    public let channelId: UUID
}
