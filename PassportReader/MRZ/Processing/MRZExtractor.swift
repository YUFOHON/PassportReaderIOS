

import Foundation

class MRZExtractor {
    
    // MARK: - Main Extraction
    
    func extractMRZ(
        from candidates: [(text: String, y: CGFloat, confidence: Float)],
        cleaner: MRZCleaner,
        validator: MRZValidator
    ) -> (lines: [String], documentType: MRZDocumentType)? {
        
        var eepCandidates: [(text: String, y: CGFloat, confidence: Float)] = []
        var mrzCandidates: [(text: String, y: CGFloat, confidence: Float)] = []
        
        for candidate in candidates {
            if validator.isEEPLine(candidate.text) {
                eepCandidates.append(candidate)
            } else if validator.isMRZLine(candidate.text) {
                mrzCandidates.append(candidate)
            }
        }
        
        // Prioritize EEP detection (single line)
        if let eepResult = extractEEP(from: eepCandidates, cleaner: cleaner, validator: validator) {
            print("@@>> eepResult: "+eepResult)
            return (lines: [eepResult], documentType: .eepChina)
        }
        
        // Extract multi-line MRZ
        return extractMultiLineMRZ(from: mrzCandidates, cleaner: cleaner, validator: validator)
    }
    
    // MARK: - EEP Extraction
    
    private func extractEEP(
        from candidates: [(text: String, y: CGFloat, confidence: Float)],
        cleaner: MRZCleaner,
        validator: MRZValidator
    ) -> String? {
        guard let bestCandidate = candidates.max(by: { $0.confidence < $1.confidence }) else {
            return nil
        }
        
        let cleanedLine = cleaner.cleanEEPLine(bestCandidate.text)
        let normalized = cleaner.cleanAndNormalizeEEP(cleanedLine)
        
        // Validate
        if validator.validateEEPMRZ(normalized) || normalized.hasPrefix("CS") {
            return normalized
        }
        
        // Return anyway if it looks like EEP
        if cleanedLine.count >= 28 && (cleanedLine.hasPrefix("CS") || cleanedLine.hasPrefix("C")) {
            return cleaner.normalizeMRZLineLength(cleanedLine, targetLength: 30)
        }
        
        return nil
    }
    
    // MARK: - Multi-Line MRZ Extraction
    
    private func extractMultiLineMRZ(
        from candidates: [(text: String, y: CGFloat, confidence: Float)],
        cleaner: MRZCleaner,
        validator: MRZValidator
    ) -> (lines: [String], documentType: MRZDocumentType)? {
        guard candidates.count >= 1 else { return nil }
        
        // Sort by vertical position (top to bottom, higher y = lower on screen in Vision coords)
        let sortedCandidates = candidates.sorted { $0.y > $1.y }
        
        // Detect document type
        let texts = sortedCandidates.map { $0.text }
        guard let documentType = detectDocumentType(from: texts) else { return nil }
        
        // Take required number of lines
        let requiredLines = documentType.lineCount
        let topCandidates = Array(sortedCandidates.prefix(min(requiredLines + 1, sortedCandidates.count)))
        
        guard topCandidates.count >= min(requiredLines, 2) else { return nil }
        
        // Clean and normalize lines
        let cleanedLines = topCandidates.map { cleaner.cleanMRZLine($0.text) }
        let normalizedLines = cleanedLines.map {
            cleaner.normalizeMRZLineLength($0, targetLength: documentType.lineLength)
        }
        
        // Take expected number of lines
        let linesToUse = Array(normalizedLines.prefix(requiredLines))
        
        return (lines: linesToUse, documentType: documentType)
    }
    
    // MARK: - Document Type Detection
    
    func detectDocumentType(from lines: [String]) -> MRZDocumentType? {
        guard !lines.isEmpty else { return nil }
        
        let firstLine = lines[0].uppercased().replacingOccurrences(of: " ", with: "")
        let lineLength = firstLine.count
        
        // Check for China EEP
        if isEEPDocument(firstLine, lineLength: lineLength, lineCount: lines.count) {
            return .eepChina
        }
        
        // TD3 Passport: 2 lines × 44 chars, starts with P
        if firstLine.hasPrefix("P") && lineLength >= 42 && lineLength <= 46 {
            return .td3
        }
        
        // Visa Type A: 2 lines × 44 chars, starts with V
        if firstLine.hasPrefix("V") && lineLength >= 42 && lineLength <= 46 {
            return .mrva
        }
        
        // TD1 ID Card: 3 lines × 30 chars
        if isTD1Document(firstLine, lineLength: lineLength) {
            return .td1
        }
        
        // TD2 or Visa Type B: 2 lines × 36 chars
        if lineLength >= 34 && lineLength <= 38 {
            return firstLine.hasPrefix("V") ? .mrvb : .td2
        }
        
        // Fallback based on length
        return fallbackDocumentType(lineLength: lineLength, lineCount: lines.count)
    }
    
    private func isEEPDocument(_ firstLine: String, lineLength: Int, lineCount: Int) -> Bool {
        // Single line starting with CS
        if firstLine.hasPrefix("CS") || firstLine.hasPrefix("C5") || firstLine.hasPrefix("C$") || firstLine.hasPrefix("C8") {
            return lineLength >= 28 && lineLength <= 32
        }
        
        // Single line starting with C (possible OCR error)
        if lineCount == 1 && firstLine.hasPrefix("C") && lineLength >= 28 && lineLength <= 32 {
            let secondChar = firstLine.dropFirst().first
            return secondChar == "S" || secondChar == "5" || secondChar == "$" || secondChar == "8" || secondChar == "<"
        }
        
        return false
    }
    
    private func isTD1Document(_ firstLine: String, lineLength: Int) -> Bool {
        let td1Prefixes = ["I", "A", "C"]
        
        guard td1Prefixes.contains(where: { firstLine.hasPrefix($0) }) else { return false }
        
        // Not CS (that's EEP)
        guard !firstLine.hasPrefix("CS") && !firstLine.hasPrefix("C5") && !firstLine.hasPrefix("C$") else { return false }
        
        return lineLength >= 28 && lineLength <= 32
    }
    
    private func fallbackDocumentType(lineLength: Int, lineCount: Int) -> MRZDocumentType? {
        if lineCount >= 2 && lineLength >= 42 {
            return .td3
        } else if lineCount >= 2 && lineLength >= 34 {
            return .td2
        } else if lineLength >= 28 && lineLength <= 32 {
            return lineCount == 1 ? .eepChina : .td1
        }
        
        return nil
    }
}
