import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    
    // THE FIX: Use didSet to notify AVFoundation when the delegate is assigned
    weak var delegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        didSet {
            output.setSampleBufferDelegate(delegate, queue: queue)
        }
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { self.setupCamera() } }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        // Ensure we don't add inputs/outputs multiple times
        guard !session.isRunning else { return }
        
        session.beginConfiguration()
        
        // Input: Back Camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) { session.addInput(input) }
        
        // Output: Frames
        if session.canAddOutput(output) {
            // We removed the setSampleBufferDelegate from here,
            // it is now handled securely by the didSet above!
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
}
