//
//  GestureView.swift
//  Lumio
//
//  Created by user on 30/01/26.
//

import SwiftUI
import UIKit

struct GestureView: UIViewRepresentable {
    var onDoubleTap: () -> Void
    var onTripleTap: () -> Void
    var onTwoFingerTap: () -> Void
    var onTwoFingerSwipe: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        // 1. Double Tap (1 Finger) -> Text
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        view.addGestureRecognizer(doubleTap)
        
        // 2. Triple Tap (1 Finger) -> Scene
        let tripleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTripleTap))
        tripleTap.numberOfTapsRequired = 3
        tripleTap.numberOfTouchesRequired = 1
        view.addGestureRecognizer(tripleTap)
        
        // Dependency: Double fails if Triple detected
        doubleTap.require(toFail: tripleTap)
        
        // 3. Two Finger Tap -> Person
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerTap))
        twoFingerTap.numberOfTapsRequired = 1
        twoFingerTap.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerTap)
        
        // 4. Two Finger Swipe -> Object
        let twoFingerSwipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerSwipe))
        twoFingerSwipe.direction = .down // Or any direction
        twoFingerSwipe.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerSwipe)
        
        // Add Up/Left/Right directions too if desired
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: GestureView
        
        init(parent: GestureView) {
            self.parent = parent
        }
        
        @objc func handleDoubleTap() { parent.onDoubleTap() }
        @objc func handleTripleTap() { parent.onTripleTap() }
        @objc func handleTwoFingerTap() { parent.onTwoFingerTap() }
        @objc func handleTwoFingerSwipe() { parent.onTwoFingerSwipe() }
    }
}
