import Foundation
import Speech
import Combine

class SpeechToTextEngine: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isListening: Bool = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    func requestPermissions() {
        // 1. Request Speech Recognition
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech Auth Status: \(status.rawValue)")
        }
        
        // 2. Request Microphone Access
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("Microphone Permission Granted: \(granted)")
        }
    }
    
    func startListening(completion: @escaping (String) -> Void) {
        guard !audioEngine.isRunning else { return }
        
        // Cancel previous task
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure Audio Session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }
            if error != nil || result?.isFinal == true {
                self.stopListening()
                completion(self.transcribedText)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
    }
    
    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            
            // THE FIX: Explicitly tell iOS to release the microphone hardware!
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Could not release audio session: \(error)")
            }
        }
        DispatchQueue.main.async { self.isListening = false }
    }
}
