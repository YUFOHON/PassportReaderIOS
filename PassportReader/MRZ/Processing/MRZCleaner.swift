//
//  MRZCleaner.swift
//  PassportReader
//

import Foundation

class MRZCleaner {
    
    // MARK: - Character Mappings
    
    private let letterToDigitMap: [Character: Character] = [
        "O": "0",
        "Q": "0",
        "D": "0",
        "I": "1",
        "L": "1",
        "Z": "2",
        "S": "5",
        "B": "8"
    ]
    
    private let digitToLetterMap: [Character: Character] = [
        "0": "O",
        "1": "I",
        "2": "Z",
        "5": "S",
        "8": "B"
    ]
    
    private let commonOCRErrors: [String: String] = [
        "«": "<",
        "»": "<",
        "‹": "<",
        "›": "<",
        "|": "<",
        "¦": "<",
        " ": "<",
        "Ć": "C",
        "Ś": "S",
        "$": "S",
        "§": "S"
    ]
    
    // MARK: - General Cleaning
    
    func cleanMRZLine(_ text: String) -> String {
        var cleaned = text.uppercased()
        
        // Apply common OCR error corrections
        for (error, correction) in commonOCRErrors {
            cleaned = cleaned.replacingOccurrences(of: error, with: correction)
        }
        
        // Remove any remaining invalid characters
        cleaned = cleaned.filter { char in
            char.isLetter || char.isNumber || char == "<"
        }
        
        return cleaned
    }
    
    func cleanEEPLine(_ text: String) -> String {
        var cleaned = text.uppercased()
        
        // Apply common OCR error corrections
        for (error, correction) in commonOCRErrors {
            cleaned = cleaned.replacingOccurrences(of: error, with: correction)
        }
        
        // EEP specific: ensure starts with CS
        if cleaned.hasPrefix("C5") || cleaned.hasPrefix("C$") || cleaned.hasPrefix("C8") {
            cleaned = "CS" + String(cleaned.dropFirst(2))
        }
        
        // Remove invalid characters
        cleaned = cleaned.filter { char in
            char.isLetter || char.isNumber || char == "<"
        }
        
        return cleaned
    }
    
    // MARK: - Normalization
    
    func normalizeMRZLineLength(_ line: String, targetLength: Int) -> String {
        if line.count == targetLength {
            return line
        } else if line.count > targetLength {
            return String(line.prefix(targetLength))
        } else {
            return line + String(repeating: "<", count: targetLength - line.count)
        }
    }
    
    // MARK: - Context-Aware Correction
    
    func correctDigitsInAlphaZone(_ text: String) -> String {
        var result = ""
        for char in text {
            if char.isNumber, let replacement = digitToLetterMap[char] {
                result.append(replacement)
            } else {
                result.append(char)
            }
        }
        return result
    }
    
    func correctLettersInNumericZone(_ text: String) -> String {
        var result = ""
        for char in text {
            if char.isLetter, let replacement = letterToDigitMap[char] {
                result.append(replacement)
            } else {
                result.append(char)
            }
        }
        return result
    }
    
    // MARK: - EEP Specific Cleaning
    
    func cleanAndNormalizeEEP(_ text: String) -> String {
        var cleaned = cleanEEPLine(text)
        
        // EEP Structure (30 chars):
        // Pos 0-1: CS (document type)
        // Pos 2-10: Document number (9 chars)
        // Pos 11: Check digit
        // Pos 12-17: Date of birth (YYMMDD)
        // Pos 18: Check digit
        // Pos 19: Sex
        // Pos 20-25: Expiry date (YYMMDD)
        // Pos 26: Check digit
        // Pos 27: Nationality indicator
        // Pos 28-29: Final check digits
        
        // Ensure proper length
        cleaned = normalizeMRZLineLength(cleaned, targetLength: 30)
        
        let chars = Array(cleaned)
        var corrected = [Character]()
        
        for (index, char) in chars.enumerated() {
            switch index {
            case 0...1:
                // Document type: should be letters (CS)
                if char.isNumber, let replacement = digitToLetterMap[char] {
                    corrected.append(replacement)
                } else {
                    corrected.append(char)
                }
                
            case 2...10:
                // Document number: alphanumeric
                corrected.append(char)
                
            case 11, 18, 26, 28, 29:
                // Check digits: should be numbers
                if char.isLetter, let replacement = letterToDigitMap[char] {
                    corrected.append(replacement)
                } else {
                    corrected.append(char)
                }
                
            case 12...17, 20...25:
                // Dates: should be numbers
                if char.isLetter, let replacement = letterToDigitMap[char] {
                    corrected.append(replacement)
                } else {
                    corrected.append(char)
                }
                
            case 19:
                // Sex: should be M, F, or <
                if char.isNumber {
                    if char == "0" {
                        corrected.append("<")
                    } else {
                        corrected.append(char)
                    }
                } else {
                    corrected.append(char)
                }
                
            case 27:
                // Nationality indicator: letter or <
                corrected.append(char)
                
            default:
                corrected.append(char)
            }
        }
        
        return String(corrected)
    }
}
