//
//  AlignmentState.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 16/1/2026.
//

import Foundation
//
//  AlignmentState.swift
//  PassportReader
//

import UIKit

enum AlignmentInstruction: String {
    case placeDocument = "Place document inside the frame"
    case moveCloser = "Move closer"
    case moveBackward = "Move backward"
    case moveLeft = "Move left"
    case moveRight = "Move right"
    case moveUp = "Move up"
    case moveDown = "Move down"
    case holdSteady = "Hold steady"
    case processing = "Processing..."
    case success = "Document captured!"
    
    var color: UIColor {
        switch self {
        case .placeDocument:
            return .white
        case .moveCloser, .moveBackward, .moveLeft, .moveRight, .moveUp, .moveDown:
            return UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0) // Yellow
        case .holdSteady:
            return UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0) // Green
        case .processing:
            return UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0) // Blue
        case .success:
            return UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0) // Bright Green
        }
    }
    
    var borderColor: UIColor {
        switch self {
        case .holdSteady, .success:
            return UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
        case .processing:
            return UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        case .moveCloser, .moveBackward, .moveLeft, .moveRight, .moveUp, .moveDown:
            return UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        default:
            return .white
        }
    }
}

struct AlignmentResult {
    let instruction: AlignmentInstruction
    let isAligned: Bool
    let confidence: CGFloat
    let detectedRect: CGRect?
    let documentType: DocumentType?
    
    static let notDetected = AlignmentResult(
        instruction: .placeDocument,
        isAligned: false,
        confidence: 0,
        detectedRect: nil,
        documentType: nil
    )
}
