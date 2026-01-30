//
//  VisionEngine.swift
//  Lumio
//
//  Created by user on 30/01/26.
//

import Vision
import AVFoundation

class VisionEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @Published var lastPrediction: String = ""
    private var currentRequestType: RequestType = .none
    private var completion: ((String) -> Void)?
    
    enum RequestType {
        case none, text, scene, object, face
    }
    
    func performAnalysis(type: RequestType, completion: @escaping (String) -> Void) {
        self.currentRequestType = type
        self.completion = completion
        // The analysis happens in the delegate method below when the next frame arrives
    }
    
    // MARK: - Camera Delegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard currentRequestType != .none, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Create Request based on type
        var request: VNRequest?
        
        switch currentRequestType {
        case .text:
            let textReq = VNRecognizeTextRequest(completionHandler: handleText)
            textReq.recognitionLevel = .accurate
            request = textReq
            
        case .scene, .object:
            // Uses Apple's internal taxonomy (thousands of objects)
            let classifyReq = VNClassifyImageRequest(completionHandler: handleClassification)
            request = classifyReq
            
        case .face:
            let faceReq = VNDetectFaceRectanglesRequest(completionHandler: handleFace)
            request = faceReq
            
        case .none: break
        }
        
        // Execute
        if let request = request {
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
            
            // Reset trigger to process only one frame
            currentRequestType = .none
        }
    }
    
    // MARK: - Handlers
    
    private func handleText(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            notify("No text found.")
            return
        }
        // Natural reading logic: join lines
        let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        notify(text.isEmpty ? "No text found." : text)
    }
    
    private func handleClassification(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation] else {
            notify("Not sure.")
            return
        }
        // Filter low confidence
        let validObs = observations.filter { $0.confidence > 0.7 }
        
        if validObs.isEmpty {
            notify("Object unclear.")
        } else {
            // For Scene: Describe top 2. For Object: Identify top 1.
            // We use the same request but format differently if needed.
            let topResult = validObs.first?.identifier ?? "Object"
            notify("This is a \(topResult)")
        }
    }
    
    private func handleFace(request: VNRequest, error: Error?) {
        guard let faces = request.results as? [VNFaceObservation] else {
            notify("No one detected.")
            return
        }
        let count = faces.count
        if count == 0 { notify("No person detected.") }
        else if count == 1 { notify("One person is in front of you.") }
        else { notify("\(count) people detected.") }
    }
    
    private func notify(_ result: String) {
        DispatchQueue.main.async {
            self.completion?(result)
        }
    }
}
