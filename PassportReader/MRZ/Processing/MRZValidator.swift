//
//  MRZValidator.swift
//  PassportReader
//

import Foundation

class MRZValidator {
    
    private let validMRZCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
    
    // MARK: - Line Validation
    
    func isMRZLine(_ text: String) -> Bool {
        let cleanText = text.replacingOccurrences(of: " ", with: "").uppercased()
        
        // Length check: 28-46 characters
        guard cleanText.count >= 28 && cleanText.count <= 46 else { return false }
        
        // Valid character percentage
        let validCharCount = cleanText.unicodeScalars.filter { validMRZCharacters.contains($0) }.count
        let validPercentage = Double(validCharCount) / Double(cleanText.count)
        
        guard validPercentage >= 0.85 else { return false }
        
        // Check specific patterns
        return isValidMRZLinePattern(cleanText) ||
               (cleanText.contains("<") && validPercentage >= 0.9)
    }
    
    func isEEPLine(_ text: String) -> Bool {
        let cleanText = text.replacingOccurrences(of: " ", with: "").uppercased()
        
        // Must be around 30 characters
        guard cleanText.count >= 28 && cleanText.count <= 32 else { return false }
        
        // Must start with CS (or common OCR errors)
        let validPrefixes = ["CS", "C5", "C$", "C8", "C<"]
        guard validPrefixes.contains(where: { cleanText.hasPrefix($0) }) else { return false }
        
        // Should have '<' separators (typically 2-5 of them)
        let delimiterCount = cleanText.filter { $0 == "<" }.count
        guard delimiterCount >= 1 else { return false }
        
        // Should have enough digits (document number + dates + check digits)
        let digitCount = cleanText.filter { $0.isNumber }.count
        guard digitCount >= 10 else { return false }
        
        return true
    }
    
    // MARK: - Pattern Validation
    
    private func isValidMRZLinePattern(_ line: String) -> Bool {
        let cleanLine = line.uppercased()
        
        // EEP Pattern
        if isEEPPattern(cleanLine) { return true }
        
        // TD3 Passport Line 1
        if isPassportLine1Pattern(cleanLine) { return true }
        
        // TD3 Passport Line 2
        if isPassportLine2Pattern(cleanLine) { return true }
        
        // TD1 ID Card Patterns
        if isTD1Pattern(cleanLine) { return true }
        
        // Visa Patterns
        if isVisaPattern(cleanLine) { return true }
        
        // Generic MRZ detection
        if isGenericMRZPattern(cleanLine) { return true }
        
        return false
    }
    
    private func isEEPPattern(_ line: String) -> Bool {
        let validPrefixes = ["CS", "C5", "C8", "C$"]
        if validPrefixes.contains(where: { line.hasPrefix($0) }) {
            if line.count >= 28 && line.count <= 32 {
                let digitCount = line.filter { $0.isNumber }.count
                return digitCount >= 10
            }
        }
        return false
    }
    
    private func isPassportLine1Pattern(_ line: String) -> Bool {
        let passportPrefixes = ["P<", "PO", "P0"]
        return passportPrefixes.contains(where: { line.hasPrefix($0) }) && line.contains("<<")
    }
    
    private func isPassportLine2Pattern(_ line: String) -> Bool {
        if line.count >= 42 {
            let digitCount = line.filter { $0.isNumber }.count
            return digitCount >= 10 && line.contains("<")
        }
        return false
    }
    
    private func isTD1Pattern(_ line: String) -> Bool {
        let td1Prefixes = ["I<", "ID", "I0", "A<", "AC", "C<"]
        return td1Prefixes.contains(where: { line.hasPrefix($0) })
    }
    
    private func isVisaPattern(_ line: String) -> Bool {
        return line.hasPrefix("V<") || line.hasPrefix("V0")
    }
    
    private func isGenericMRZPattern(_ line: String) -> Bool {
        if line.contains("<<") && line.count >= 30 {
            return true
        }
        
        let digitCount = line.filter { $0.isNumber }.count
        let hasDatePattern = digitCount >= 6 && line.contains("<")
        
        return hasDatePattern && line.count >= 28
    }
    
    // MARK: - Full MRZ Validation
    
    func validateMRZ(_ mrz: String) -> Bool {
        let lines = mrz.components(separatedBy: "\n")
        
        if lines.count == 1 {
            return validateEEPMRZ(lines[0])
        }
        
        return validateMultiLineMRZ(lines)
    }
    
    func validateEEPMRZ(_ mrz: String) -> Bool {
        let cleanMRZ = mrz.replacingOccurrences(of: " ", with: "")
        
        guard cleanMRZ.count == 30 else { return false }
        guard cleanMRZ.hasPrefix("CS") else { return false }
        
        let chars = Array(cleanMRZ)
        
        // Verify check digit positions contain valid characters
        let checkPositions = [11, 18, 26, 28, 29]
        for pos in checkPositions {
            if pos < chars.count {
                let char = chars[pos]
                if !char.isNumber && char != "<" {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func validateMultiLineMRZ(_ lines: [String]) -> Bool {
        guard lines.count >= 2 else { return false }
        
        let line1 = lines[0]
        let line2 = lines[1]
        
        let lengthDiff = abs(line1.count - line2.count)
        guard lengthDiff <= 2 else { return false }
        
        let validStarts = ["P<", "P0", "PO", "I<", "ID", "I0", "AC", "A<", "C<", "V<", "V0"]
        let hasValidStart = validStarts.contains { line1.hasPrefix($0) } ||
                           line1.first == "P" ||
                           line1.first == "V"
        
        let line2DigitCount = line2.filter { $0.isNumber }.count
        let hasEnoughDigits = line2DigitCount >= 6
        
        return hasValidStart && hasEnoughDigits
    }
    
    // MARK: - Check Digit Calculation
    
    func calculateCheckDigit(_ input: String) -> Int {
        let weights = [7, 3, 1]
        var sum = 0
        
        for (index, char) in input.enumerated() {
            let value: Int
            
            if char == "<" {
                value = 0
            } else if char.isNumber {
                value = Int(String(char)) ?? 0
            } else if char.isLetter {
                value = Int(char.asciiValue ?? 0) - 55
            } else {
                value = 0
            }
            
            sum += value * weights[index % 3]
        }
        
        return sum % 10
    }
    
    func verifyCheckDigit(data: String, checkDigit: Character) -> Bool {
        guard let expectedDigit = Int(String(checkDigit)) else { return checkDigit == "<" }
        let calculatedDigit = calculateCheckDigit(data)
        return calculatedDigit == expectedDigit
    }
}
