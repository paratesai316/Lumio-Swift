import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var vision = VisionEngine()
    @StateObject private var speech = SpeechEngine()
    @StateObject private var dictation = SpeechToTextEngine()
    
    @State private var showSettings = false
    @State private var currentStatus = "Lumio Ready"
    
    // MARK: - Add Person State Variables
    @State private var isAddingPerson = false
    @State private var pendingFaceSignature: [CGPoint]? = nil
    @State private var nameInput = ""
    @State private var isTyping = false
    @FocusState private var isKeyboardFocused: Bool
    
    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
                .onAppear {
                    camera.checkPermissions()
                    
                    // THE FIX: Request both Mic and Speech upfront!
                    dictation.requestPermissions()
                    
                    camera.delegate = vision
                    
                    vision.onUnknownFaceDetected = { signature in
                        self.pendingFaceSignature = signature
                        self.isAddingPerson = true
                        let prompt = "Unknown person detected. Two-finger tap to speak their name, triple tap to type, or double tap to cancel."
                        self.currentStatus = "Waiting for name..."
                        speech.speak(prompt)
                    }
                }
            // Context-Aware Gestures
            GestureView(
                onDoubleTap: {
                    if isAddingPerson { handleCancel() }
                    else { trigger(.text) }
                },
                onTripleTap: {
                    if isAddingPerson { handleTypeMode() }
                    else { trigger(.scene) }
                },
                onTwoFingerTap: {
                    if isAddingPerson { handleSpeakMode() }
                    else { trigger(.face) }
                },
                onTwoFingerSwipe: {
                    if !isAddingPerson { trigger(.object) }
                }
            )
            
            // MARK: - UI Overlays
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
                    .disabled(isAddingPerson) // Disable settings while adding someone
                }
                Spacer()
                
                // Typing UI Overlay
                if isTyping {
                    VStack {
                        TextField("Enter name...", text: $nameInput)
                            .focused($isKeyboardFocused)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        Button("Save Name") {
                            savePerson(name: nameInput)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .padding()
                }
                
                // Listening UI Overlay
                if dictation.isListening {
                    Text("Listening: \(dictation.transcribedText)")
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
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
    
    // MARK: - Standard Actions
    func trigger(_ type: VisionEngine.RequestType) {
        speech.stop()
        speech.speak("Scanning...")
        currentStatus = "Scanning..."
        
        vision.performAnalysis(type: type) { result in
            self.currentStatus = result
            speech.speak(result)
        }
    }
    
    // MARK: - Add Person Actions
    
    func handleCancel() {
        speech.stop()
        isAddingPerson = false
        pendingFaceSignature = nil
        isTyping = false
        isKeyboardFocused = false
        if dictation.isListening { dictation.stopListening() }
        currentStatus = "Cancelled."
        speech.speak("Cancelled adding person.")
    }
    
    func handleTypeMode() {
        speech.stop()
        speech.speak("Keyboard open. Type the name and press save.")
        isTyping = true
        isKeyboardFocused = true // Automatically pops up the keyboard
    }
    
    func handleSpeakMode() {
        speech.stop()
        speech.speak("Listening for name.")
        
        // Add a slight delay so it doesn't transcribe its own voice saying "Listening"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dictation.startListening { finalName in
                if !finalName.isEmpty {
                    savePerson(name: finalName)
                } else {
                    speech.speak("I didn't catch that. Double tap to cancel.")
                }
            }
            
            // Automatically stop recording after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                dictation.stopListening()
            }
        }
    }
    
    func savePerson(name: String) {
        guard let signature = pendingFaceSignature, !name.isEmpty else { return }
        // Save to Vision Engine's memory dictionary
        vision.knownFaces[name] = signature
        
        // Reset state
        isAddingPerson = false
        pendingFaceSignature = nil
        isTyping = false
        isKeyboardFocused = false
        nameInput = ""
        
        speech.speak("Saved \(name). I will recognize them next time.")
        currentStatus = "Saved \(name)."
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
