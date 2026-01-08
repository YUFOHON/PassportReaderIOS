//
//  BaseMrzParser.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 7/1/2026.
//

import Foundation
import os.log

// MARK: - BaseMrzParser
class BaseMrzParser: MrzParser {
    static let logger = Logger(subsystem: "com.example.reader.mrz", category: "MrzParser")
    
    func canParse(_ line: String) -> Bool {
        fatalError("Must override canParse in subclass")
    }
    
    func parse(_ line: String) -> [String: String]? {
        fatalError("Must override parse in subclass")
    }
    
    func getDocumentType() -> String {
        fatalError("Must override getDocumentType in subclass")
    }
    
    // MARK: - Protected Helper Methods
    
    func cleanMrzCharacters(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "O", with: "0")  // Letter O to zero
            .replacingOccurrences(of: "Q", with: "0")
            .replacingOccurrences(of: "D", with: "0")
            .replacingOccurrences(of: "I", with: "1")  // Letter I to one
            .replacingOccurrences(of: "l", with: "1")  // Lowercase L to one
            .replacingOccurrences(of: "Z", with: "2")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "<", with: "")   // Remove filler characters
            .uppercased()
    }
    
    func isValidDate(_ date: String) -> Bool {
        guard date.count == 6 else { return false }
        
        let yearString = String(date.prefix(2))
        let monthString = String(date.dropFirst(2).prefix(2))
        let dayString = String(date.suffix(2))
        
        guard let year = Int(yearString),
              let month = Int(monthString),
              let day = Int(dayString) else {
            return false
        }
        
        // Basic date validation
        if month < 1 || month > 12 { return false }
        if day < 1 || day > 31 { return false }
        
        // More strict validation for months with fewer days
        if (month == 4 || month == 6 || month == 9 || month == 11) && day > 30 {
            return false
        }
        if month == 2 && day > 29 {
            return false
        }
        
        return true
    }
    
    func validateCheckDigit(_ data: String, _ checkDigit: Character) -> Bool {
        let weights = [7, 3, 1]
        var sum = 0
        
        for (i, c) in data.enumerated() {
            let value: Int
            
            if c == "<" {
                value = 0
            } else if c.isNumber {
                value = Int(String(c)) ?? 0
            } else if c.isLetter {
                value = Int(c.asciiValue ?? 0) - Int(Character("A").asciiValue ?? 0) + 10
            } else {
                return false // Invalid character
            }
            
            sum += value * weights[i % 3]
        }
        
        let calculatedCheck = sum % 10
        
        // Handle check digit
        let providedCheck: Int
        if checkDigit == "<" {
            providedCheck = 0
        } else if checkDigit.isNumber {
            providedCheck = Int(String(checkDigit)) ?? -1
        } else {
            return false
        }
        
        return calculatedCheck == providedCheck
    }
    
    func fixDateOcrErrors(_ date: String) -> String {
        guard date.count == 6 else { return date }
        
        var fixed = Array(date)
        
        // Fix common OCR errors in dates
        for i in 0..<fixed.count {
            let c = fixed[i]
            
            // Common OCR misreads for digits
            if c == "O" || c == "Q" || c == "D" {
                fixed[i] = "0"
            } else if c == "I" || c == "l" {
                fixed[i] = "1"
            } else if c == "Z" {
                fixed[i] = "2"
            } else if c == "S" {
                fixed[i] = "5"
            } else if c == "B" {
                fixed[i] = "8"
            }
        }
        
        return String(fixed)
    }
}
