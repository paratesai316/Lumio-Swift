import Vision
import AVFoundation
import Combine
import CoreML

class VisionEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @Published var lastPrediction: String = ""
    private var currentRequestType: RequestType = .none
    private var completion: ((String) -> Void)?
    
    // MARK: - Face Memory & Persistence
    
    // Triggers UI popup when an unknown signature is detected
    var onUnknownFaceDetected: (([CGPoint]) -> Void)?
    
    private let facesKey = "LumioSavedFaces"
    
    // Stores the 76-point geometric signatures of known faces.
    // The `didSet` observer automatically saves to the iPad's hard drive whenever a new face is added!
    var knownFaces: [String: [CGPoint]] = [:] {
        didSet {
            saveFacesToDisk()
        }
    }
    
    // Load saved faces the moment the engine initializes
    override init() {
        super.init()
        loadFacesFromDisk()
    }
    
    // MARK: - CoreML Setup
    
    // Lazy loads the tiny 6.3MB INT8 model
    lazy var objectDetectionModel: VNCoreMLModel? = {
        do {
            let config = MLModelConfiguration()
            let model = try MobileNetV2Int8LUT(configuration: config).model
            return try VNCoreMLModel(for: model)
        } catch {
            print("Failed to load CoreML model: \(error)")
            return nil
        }
    }()
    
    enum RequestType {
        case none, text, scene, object, face
    }
    
    func performAnalysis(type: RequestType, completion: @escaping (String) -> Void) {
        self.currentRequestType = type
        self.completion = completion
    }
    
    // MARK: - Camera Delegate (The Router)
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard currentRequestType != .none, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        var request: VNRequest?
        
        switch currentRequestType {
        case .text:
            let textReq = VNRecognizeTextRequest(completionHandler: handleText)
            textReq.recognitionLevel = .accurate
            request = textReq
            
        case .scene:
            request = VNClassifyImageRequest(completionHandler: handleScene)
            
        case .object:
            guard let mlModel = objectDetectionModel else {
                notify("Model not loaded.")
                currentRequestType = .none
                return
            }
            
            let mlRequest = VNCoreMLRequest(model: mlModel, completionHandler: handleCoreMLObject)
            // Center crop prevents the iPad from stretching objects and confusing the AI
            mlRequest.imageCropAndScaleOption = .centerCrop
            request = mlRequest
            
        case .face:
            recognizeFace(in: pixelBuffer)
            currentRequestType = .none
            return
            
        case .none: break
        }
        
        // Execute standard requests
        if let request = request {
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
            currentRequestType = .none
        }
    }
    
    // MARK: - Geometric Face Recognition
    
    private func recognizeFace(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNFaceObservation],
                  let face = results.first,
                  let landmarks = face.landmarks,
                  let allPoints = landmarks.allPoints else {
                self?.notify("No face clearly visible.")
                return
            }
            
            let currentSignature = allPoints.normalizedPoints
            
            var bestMatchName: String? = nil
            var bestDistance: CGFloat = .infinity
            
            // Compare the 76 points with known faces
            for (name, knownSignature) in self.knownFaces {
                let distance = self.calculateSignatureDifference(sig1: currentSignature, sig2: knownSignature)
                
                print("📐 Geometric Drift to \(name): \(distance)")
                
                // 0.06 is the empirical sweet spot for geometric landmark arrays
                if distance < 0.06 && distance < bestDistance {
                    bestDistance = distance
                    bestMatchName = name
                }
            }
            
            if let name = bestMatchName {
                self.notify("\(name) is in front of you.")
            } else {
                self.notify("Unknown person.")
                DispatchQueue.main.async {
                    self.onUnknownFaceDetected?(currentSignature)
                }
            }
        }
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
    }
    
    // Helper math function to calculate average drift per landmark
    private func calculateSignatureDifference(sig1: [CGPoint], sig2: [CGPoint]) -> CGFloat {
        guard sig1.count == sig2.count, !sig1.isEmpty else { return .infinity }
        var totalDrift: CGFloat = 0
        
        for i in 0..<sig1.count {
            let dx = sig1[i].x - sig2[i].x
            let dy = sig1[i].y - sig2[i].y
            totalDrift += sqrt(dx*dx + dy*dy)
        }
        
        return totalDrift / CGFloat(sig1.count)
    }
    
    // MARK: - Handlers
    
    private func handleCoreMLObject(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation],
              let topResult = observations.first else {
            notify("Cannot identify object.")
            return
        }
        
        // MobileNet V2 INT8 confidence threshold lowered to 0.20
        if topResult.confidence > 0.20 {
            let cleanName = topResult.identifier.components(separatedBy: ",").first ?? topResult.identifier
            let spokenName = cleanName.trimmingCharacters(in: .whitespaces).lowercased()
            
            let vowels: [Character] = ["a", "e", "i", "o", "u"]
            let article = vowels.contains(spokenName.first ?? " ") ? "an" : "a"
            
            notify("This is \(article) \(spokenName).")
        } else {
            notify("Object unclear, try getting closer.")
        }
    }
    
    private func handleScene(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation] else {
            notify("Scene unclear.")
            return
        }
        
        let validObs = observations.filter { $0.confidence > 0.6 }
        
        if validObs.count >= 2 {
            let item1 = validObs[0].identifier
            let item2 = validObs[1].identifier
            notify("This looks like a scene with \(item1) and \(item2).")
        } else if let top = validObs.first {
            notify("This appears to be \(top.identifier).")
        } else {
            notify("Scene unclear.")
        }
    }
    
    private func handleText(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            notify("No text found.")
            return
        }
        let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        notify(text.isEmpty ? "No text found." : text)
    }
    
    private func notify(_ result: String) {
        DispatchQueue.main.async {
            self.completion?(result)
        }
    }
    
    // MARK: - Data Persistence Methods
    
    private func saveFacesToDisk() {
        // CGPoint natively conforms to Codable, allowing us to easily convert the math to JSON
        if let encoded = try? JSONEncoder().encode(knownFaces) {
            UserDefaults.standard.set(encoded, forKey: facesKey)
            print("💾 Saved \(knownFaces.count) faces to permanent storage.")
        }
    }
    
    private func loadFacesFromDisk() {
        if let data = UserDefaults.standard.data(forKey: facesKey),
           let decoded = try? JSONDecoder().decode([String: [CGPoint]].self, from: data) {
            self.knownFaces = decoded
            print("💾 Loaded \(decoded.count) faces from permanent storage.")
        }
    }
}
