import SwiftUI
import AVFoundation

@MainActor @Observable
final class ScannerModel: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    var permissionDenied = false
    var unavailable = false
    var scanned: String?
    private var lastValue = ""
    private var lastScan = Date.distantPast

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted { permissionDenied = true; return }
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { permissionDenied = true; return }
        }
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera) else { unavailable = true; return }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .qr]
        } else { unavailable = true }
        session.commitConfiguration()
        if !unavailable { Task.detached { [session] in session.startRunning() } }
    }

    func stop() { Task.detached { [session] in session.stopRunning() } }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        Task { @MainActor in
            let value = Barcode.normalized(code)
            guard value != lastValue || Date.now.timeIntervalSince(lastScan) > 1.5 else { return }
            lastValue = value
            lastScan = .now
            scanned = value
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView { let view = PreviewView(); view.layerSession.session = session; return view }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var layerSession: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override init(frame: CGRect) { super.init(frame: frame); layerSession.videoGravity = .resizeAspectFill }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

struct BarcodeSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var model = ScannerModel()
    @State private var manual = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    CameraPreview(session: model.session)
                    RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 3).frame(width: 270, height: 180)
                }
                .frame(maxWidth: .infinity).frame(height: 350).clipShape(RoundedRectangle(cornerRadius: 22))
                if model.permissionDenied { Label("Camera access denied. Use manual entry or enable access in Settings.", systemImage: "camera.fill").foregroundStyle(Theme.amber) }
                if model.unavailable { Label("Camera unavailable. Enter a barcode below.", systemImage: "camera.fill").foregroundStyle(Theme.amber) }
                HStack {
                    TextField("Enter barcode", text: $manual).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button("Use") { let value = Barcode.normalized(manual); if !value.isEmpty { onScan(value) } }.disabled(manual.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Align one barcode inside the frame. The scan only looks up a product; it never posts a transaction.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { dismiss() } }
            .task { await model.start() }
            .onDisappear { model.stop() }
            .onChange(of: model.scanned) { _, value in
                if let value { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onScan(value) }
            }
        }
    }
}
