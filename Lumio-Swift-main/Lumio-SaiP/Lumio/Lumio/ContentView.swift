//
//  ContentView.swift
//  Lumio
//
//  Created by user on 30/01/26.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var vision = VisionEngine()
    @StateObject private var speech = SpeechEngine()
    
    @State private var showSettings = false
    @State private var currentStatus = "Lumio Ready"
    
    var body: some View {
        ZStack {
            // 1. Camera Preview
            CameraPreview(session: camera.session)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    camera.checkPermissions()
                    camera.delegate = vision // Connect Camera to Vision
                }
            
            // 2. Gesture Overlay (Invisible)
            GestureView(
                onDoubleTap: { trigger(.text) },
                onTripleTap: { trigger(.scene) },
                onTwoFingerTap: { trigger(.face) },
                onTwoFingerSwipe: { trigger(.object) }
            )
            
            // 3. UI Overlays
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
                
                // Status Text (for debugging/visual confirmation)
                Text(currentStatus)
                    .font(.title2)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(speechEngine: speech)
        }
        .onAppear {
            speech.speak("Lumio Ready.")
        }
    }
    
    func trigger(_ type: VisionEngine.RequestType) {
        speech.stop()
        speech.speak("Scanning...")
        currentStatus = "Scanning..."
        
        vision.performAnalysis(type: type) { result in
            self.currentStatus = result
            speech.speak(result)
        }
    }
}

// Helper: SwiftUI View for Camera Stream
struct CameraPreview: UIViewRepresentable {
    var session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.frame
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
