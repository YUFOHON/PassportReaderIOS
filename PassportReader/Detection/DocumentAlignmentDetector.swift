//
//  DocumentAlignmentDetector.swift
//  PassportReader
//

import UIKit
import Vision

class DocumentAlignmentDetector {
    
    // MARK: - Properties
    private weak var guidanceOverlay: MRZGuidanceOverlay?
    private weak var previewView: UIView?
    
    // Thresholds
    private let sizeThresholdMin: CGFloat = 0.70  // Document should be at least 70% of guide box
    private let sizeThresholdMax: CGFloat = 1.15  // Document should not exceed 115% of guide box
    private let centerOffsetThreshold: CGFloat = 0.08  // 8% of guide box dimension
    private let overlapThreshold: CGFloat = 0.85  // 85% overlap required
    
    // Cached values for performance
    private var cachedGuideBoxFrame: CGRect = .zero
    private var _cachedPreviewBounds: CGRect = .zero
    
    private var isCroppedMode: Bool = false
    private var cropOffset: CGPoint = .zero
    
    var cachedPreviewBounds: CGRect {
        return _cachedPreviewBounds  // rename internal property
    }
    
    // MARK: - Initialization
    init(guidanceOverlay: MRZGuidanceOverlay, previewView: UIView) {
        self.guidanceOverlay = guidanceOverlay
        self.previewView = previewView
    }
    
    // MARK: - Cache Update
    func updateCachedValues() {
        cachedGuideBoxFrame = guidanceOverlay?.guideBoxFrame ?? .zero
        _cachedPreviewBounds = previewView?.bounds ?? .zero
//        print("📐 Cached values updated - GuideBox: \(cachedGuideBoxFrame), Preview: \(cachedPreviewBounds)")
    }
    
    // MARK: - Alignment Detection
    func analyzeAlignment(observation: VNRectangleObservation,isCropped: Bool = false) -> AlignmentResult {
        guard cachedGuideBoxFrame != .zero, cachedPreviewBounds != .zero else {
            return .notDetected
        }
        
        let documentRect: CGRect 
        if isCropped {
            // Vision coords are relative to guide box when cropped
            documentRect = convertCroppedToUIKitCoordinates(observation.boundingBox)
        } else {
            documentRect = convertToUIKitCoordinates(observation.boundingBox)
        }
        // Detect document type based on aspect ratio
        let aspectRatio = documentRect.width / documentRect.height
        let documentType = DocumentType.detect(from: aspectRatio)
        
        // Calculate alignment metrics
        let sizeRatio = calculateSizeRatio(documentRect: documentRect)
        let centerOffset = calculateCenterOffset(documentRect: documentRect)
        let overlapRatio = calculateOverlapRatio(documentRect: documentRect)
        
        print("sizeRatio is: \(sizeRatio) centerOffset is: \(centerOffset) overlapRatio is \(overlapRatio)")

        
        // Determine instruction
        let instruction = determineInstruction(
            sizeRatio: sizeRatio,
            centerOffset: centerOffset,
            overlapRatio: overlapRatio
        )
        
        // Calculate overall confidence
        let confidence = calculateConfidence(
            sizeRatio: sizeRatio,
            centerOffset: centerOffset,
            overlapRatio: overlapRatio
        )
        
        let isAligned = instruction == .holdSteady
        
        return AlignmentResult(
            instruction: instruction,
            isAligned: isAligned,
            confidence: confidence,
            detectedRect: documentRect,
            documentType: documentType
        )
    }
    
    private func convertCroppedToUIKitCoordinates(_ visionRect: CGRect) -> CGRect {
        // Vision coordinates are now relative to the cropped guide box
        let x = cachedGuideBoxFrame.minX + visionRect.minX * cachedGuideBoxFrame.width
        let y = cachedGuideBoxFrame.minY + (1 - visionRect.maxY) * cachedGuideBoxFrame.height
        let width = visionRect.width * cachedGuideBoxFrame.width
        let height = visionRect.height * cachedGuideBoxFrame.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Coordinate Conversion
    private func convertToUIKitCoordinates(_ visionRect: CGRect) -> CGRect {
        // Vision coordinates: origin at bottom-left, normalized 0-1
        // UIKit coordinates: origin at top-left
        
        let x = visionRect.minX * cachedPreviewBounds.width
        let y = (1 - visionRect.maxY) * cachedPreviewBounds.height
        let width = visionRect.width * cachedPreviewBounds.width
        let height = visionRect.height * cachedPreviewBounds.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Alignment Calculations
    private func calculateSizeRatio(documentRect: CGRect) -> CGFloat {
        let widthRatio = documentRect.width / cachedGuideBoxFrame.width
        let heightRatio = documentRect.height / cachedGuideBoxFrame.height
        return (widthRatio + heightRatio) / 2
    }
    
    private func calculateCenterOffset(documentRect: CGRect) -> CGPoint {
        let documentCenter = CGPoint(
            x: documentRect.midX,
            y: documentRect.midY
        )
        let guideCenter = CGPoint(
            x: cachedGuideBoxFrame.midX,
            y: cachedGuideBoxFrame.midY
        )
        
        return CGPoint(
            x: (documentCenter.x - guideCenter.x) / cachedGuideBoxFrame.width,
            y: (documentCenter.y - guideCenter.y) / cachedGuideBoxFrame.height
        )
    }
    
    private func calculateOverlapRatio(documentRect: CGRect) -> CGFloat {
        let intersection = documentRect.intersection(cachedGuideBoxFrame)
        guard !intersection.isNull else { return 0 }
        
        let intersectionArea = intersection.width * intersection.height
        let guideBoxArea = cachedGuideBoxFrame.width * cachedGuideBoxFrame.height
        
        return intersectionArea / guideBoxArea
    }
    
    // MARK: - Instruction Determination
    private func determineInstruction(sizeRatio: CGFloat, centerOffset: CGPoint, overlapRatio: CGFloat) -> AlignmentInstruction {
        
        // Check size first
        if sizeRatio < sizeThresholdMin {
            return .moveCloser
        }
        
        if sizeRatio > sizeThresholdMax {
            return .moveBackward
        }
        
        // Check horizontal position
        if centerOffset.x < -centerOffsetThreshold {
            return .moveRight  // Document is to the left, move right
        }
        
        if centerOffset.x > centerOffsetThreshold {
            return .moveLeft   // Document is to the right, move left
        }
        
        // Check vertical position
        if centerOffset.y < -centerOffsetThreshold {
            return .moveDown   // Document is above, move down
        }
        
        if centerOffset.y > centerOffsetThreshold {
            return .moveUp     // Document is below, move up
        }
        
        // Check overlap
        if overlapRatio < overlapThreshold {
            return .placeDocument
        }
        
        // All checks passed
        return .holdSteady
    }
    
    // MARK: - Confidence Calculation
    private func calculateConfidence(sizeRatio: CGFloat, centerOffset: CGPoint, overlapRatio: CGFloat) -> CGFloat {
        // Size confidence (0-1)
        let idealSizeRatio: CGFloat = 1.0
        let sizeConfidence = max(0, 1 - abs(sizeRatio - idealSizeRatio) * 2)
        
        // Position confidence (0-1)
        let offsetMagnitude = sqrt(centerOffset.x * centerOffset.x + centerOffset.y * centerOffset.y)
        let positionConfidence = max(0, 1 - offsetMagnitude / centerOffsetThreshold)
        
        // Overlap confidence
        let overlapConfidence = min(1, overlapRatio / overlapThreshold)
        
        // Weighted average
        return (sizeConfidence * 0.3 + positionConfidence * 0.4 + overlapConfidence * 0.3)
    }
    
    // MARK: - Guide Box Access
    var guideBoxFrame: CGRect {
        return cachedGuideBoxFrame
    }
}
