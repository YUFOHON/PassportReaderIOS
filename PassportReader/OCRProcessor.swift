//
//  OCRProcessor.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 14/1/2026.
//

import Foundation
import Vision

class OCRProcessor {
    
    private let TAG = "OCRProcessor"
    
    struct MRZCandidate {
        let text: String
        let normalizedY: CGFloat
        let confidence: Float
        let boundingBox: CGRect
    }
    
    func extractMRZCandidates(_ observations: [VNRecognizedTextObservation],
                             viewHeight: CGFloat) -> [MRZCandidate] {
        
        var candidates: [MRZCandidate] = []
        
        print("📝 Processing \(observations.count) text observations")
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            
            // Calculate normalized Y position (0 = top, 1 = bottom)
            // Vision framework uses bottom-left origin, so we need to invert
            let normalizedY = 1.0 - observation.boundingBox.midY
            
            // Filter potential MRZ lines
            if isPotentialMRZLine(text) {
                let candidate = MRZCandidate(
                    text: text,
                    normalizedY: normalizedY,
                    confidence: confidence,
                    boundingBox: observation.boundingBox
                )
                candidates.append(candidate)
                
                print("   ✓ MRZ Candidate: '\(text)' (Y: \(String(format: "%.2f", normalizedY)), Conf: \(String(format: "%.2f", confidence)))")
            }
        }
        
        // Sort by Y position (top to bottom)
        candidates.sort { $0.normalizedY < $1.normalizedY }
        
        print("📊 Total MRZ candidates: \(candidates.count)")
        
        return candidates
    }
    
    private func isPotentialMRZLine(_ text: String) -> Bool {
        // Remove spaces for analysis
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        
        // MRZ lines are typically 28-44 characters
        guard cleaned.count >= 20 && cleaned.count <= 50 else {
            return false
        }
        
        // Check for MRZ characteristics
        let hasAngleBrackets = cleaned.contains("<")
        let hasMultipleUppercase = cleaned.range(of: "[A-Z]{5,}", options: .regularExpression) != nil
        let hasNumbers = cleaned.range(of: "[0-9]+", options: .regularExpression) != nil
        
        // Must have either angle brackets or multiple uppercase letters
        if hasAngleBrackets || hasMultipleUppercase {
            return true
        }
        
        // Or be mostly alphanumeric with numbers
        let alphanumericCount = cleaned.filter { $0.isLetter || $0.isNumber }.count
        if Double(alphanumericCount) / Double(cleaned.count) > 0.8 && hasNumbers {
            return true
        }
        
        return false
    }
    
    func filterMRZLines(_ candidates: [MRZCandidate]) -> [String] {
        guard !candidates.isEmpty else {
            return []
        }
        
        // Group candidates by vertical proximity
        var groups: [[MRZCandidate]] = []
        var currentGroup: [MRZCandidate] = [candidates[0]]
        
        for i in 1..<candidates.count {
            let current = candidates[i]
            let previous = candidates[i-1]
            
            // If Y positions are close (within 0.15 of normalized space), same group
            if abs(current.normalizedY - previous.normalizedY) < 0.15 {
                currentGroup.append(current)
            } else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [current]
            }
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        // Select best candidate from each group
        var selectedLines: [String] = []
        
        for group in groups {
            // Sort by confidence and length
            let sorted = group.sorted { candidate1, candidate2 in
                let len1 = candidate1.text.replacingOccurrences(of: " ", with: "").count
                let len2 = candidate2.text.replacingOccurrences(of: " ", with: "").count
                
                if abs(len1 - len2) > 5 {
                    return len1 > len2
                }
                return candidate1.confidence > candidate2.confidence
            }
            
            if let best = sorted.first {
                selectedLines.append(best.text)
            }
        }
        
        print("🎯 Filtered to \(selectedLines.count) MRZ lines")
        
        return selectedLines
    }
}
