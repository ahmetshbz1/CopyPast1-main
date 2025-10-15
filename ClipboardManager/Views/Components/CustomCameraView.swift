import SwiftUI
import AVFoundation

// MARK: - Camera Preview Layer
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else { return }
        layer.session = session
        layer.frame = uiView.bounds
        layer.connection?.videoOrientation = .portrait
    }
}

// MARK: - Capture Controller
final class CameraSessionController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    @Published var isTorchOn: Bool = false
    @Published var position: AVCaptureDevice.Position = .back
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var captureHandler: ((Data) -> Void)?
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Input
        if let input = makeVideoInput(position: position), session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
        }
        
        // Output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        
        session.commitConfiguration()
    }
    
    private func makeVideoInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualWideCamera, .builtInTripleCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else { return nil }
        return try? AVCaptureDeviceInput(device: device)
    }
    
    func start() {
        sessionQueue.async {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
    
    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }
    
    func switchCamera() {
        sessionQueue.async {
            self.position = (self.position == .back) ? .front : .back
            self.session.beginConfiguration()
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            if let newInput = self.makeVideoInput(position: self.position) {
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                }
            }
            self.session.commitConfiguration()
        }
    }
    
    func toggleTorch() {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = device.torchMode == .on ? .off : .on
                self.isTorchOn = device.torchMode == .on
                device.unlockForConfiguration()
            } catch { }
        }
    }
    
    func capture(_ handler: @escaping (Data) -> Void) {
        self.captureHandler = handler
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        if let device = videoDeviceInput?.device, device.hasFlash {
            settings.flashMode = isTorchOn ? .on : .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        captureHandler?(data)
        captureHandler = nil
    }
}

// MARK: - SwiftUI Camera View
struct CustomCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = CameraSessionController()
    let onCaptureImage: (UIImage) -> Void
    
    var body: some View {
        ZStack {
            CameraPreview(session: controller.session)
                .ignoresSafeArea()
            
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Button(action: { controller.toggleTorch() }) {
                        Image(systemName: controller.isTorchOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Spacer()
                
                // Bottom controls
                HStack {
                    Button(action: { controller.switchCamera() }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(14)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Button(action: capture) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.15)).frame(width: 78, height: 78)
                            Circle().fill(Color.white).frame(width: 64, height: 64)
                        }
                    }
                    Spacer()
                    // Placeholder to balance layout
                    Color.clear.frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "camera.metering.center.weighted")
                                .opacity(0)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 28)
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }
    
    private func capture() {
        controller.capture { data in
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    onCaptureImage(image)
                    dismiss()
                }
            }
        }
    }
}
