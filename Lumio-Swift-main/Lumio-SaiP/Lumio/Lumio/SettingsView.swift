//
//  SettingsView.swift
//  Lumio
//
//  Created by user on 30/01/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var speechEngine: SpeechEngine
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice Settings")) {
                    Text("Speech Rate: \(String(format: "%.2f", speechEngine.speechRate))")
                    // Slider range 0.1 to 1.0 (Apple's AVSpeech bounds)
                    Slider(value: $speechEngine.speechRate, in: 0.1...1.0, step: 0.1)
                }
                
                Section(header: Text("Gestures Guide")) {
                    Text("Double Tap: Read Text")
                    Text("Triple Tap: Describe Scene")
                    Text("2-Finger Swipe: Identify Object")
                    Text("2-Finger Tap: Detect People")
                }
                
                Section {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
