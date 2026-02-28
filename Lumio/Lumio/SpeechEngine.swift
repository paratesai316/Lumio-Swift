//
//  SpeechEngine.swift
//  Lumio
//
//  Created by user on 30/01/26.
//

import AVFoundation
import UIKit
import Combine

class SpeechEngine: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var speechRate: Float = 0.5 // Default Apple rate (0.0 - 1.0)
    
    override init() {
        super.init()
        // Configure audio session to play even if switch is on silent
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio Session Error: \(error)")
        }
    }
    
    func speak(_ text: String) {
        // THE FIX: Force the session into Playback mode before every single speech
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio Session Error: \(error)")
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = speechRate
        synthesizer.speak(utterance)
    }
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
