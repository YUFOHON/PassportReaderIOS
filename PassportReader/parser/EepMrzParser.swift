//
//  EepMrzParser.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 7/1/2026.
//

import Foundation

class EepMrzParser: BaseMrzParser {
    
    override func canParse(_ line: String) -> Bool {
        // EEP MRZ is 30 characters
        if line.count < 28 || line.count > 32 {
            return false
        }
        
        // Should start with "CS" (with OCR error tolerance)
        if !line.hasPrefix("CS") && !line.hasPrefix("C5") && !line.hasPrefix("C$") {
            return false
        }
        
        // Should contain date patterns (6 consecutive digits appear twice: expiry and DOB)
        let datePattern = "\\d{6}"
        guard let regex = try? NSRegularExpression(pattern: datePattern) else {
            return false
        }
        
        let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
        
        // Should have at least 2 date patterns (DOB and Expiry)
        return matches.count >= 2
    }
    
    override func parse(_ line: String) -> [String: String]? {
        do {
            var mutableLine = line
            
            // Clean up common OCR errors for "CS"
            if mutableLine.hasPrefix("C5") {
                mutableLine = "CS" + String(mutableLine.dropFirst(2))
            } else if mutableLine.hasPrefix("C$") {
                mutableLine = "CS" + String(mutableLine.dropFirst(2))
            }
            
            // Ensure line is exactly 30 characters
            if mutableLine.count < 30 {
                Self.logger.debug("EEP: Line too short: \(mutableLine.count)")
                return nil
            }
            
            // Truncate if slightly longer
            mutableLine = String(mutableLine.prefix(30))
            
            // EEP MRZ Format (30 characters total)
            let docType = String(mutableLine.prefix(2))
            let docNum = String(mutableLine.dropFirst(2).prefix(9))
            let docNumCheck = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 11)]
            let expiry = String(mutableLine.dropFirst(13).prefix(6))
            let expiryCheck = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 19)]
            let dob = String(mutableLine.dropFirst(21).prefix(6))
            let dobCheck = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 27)]
            let finalCheck = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 29)]
            
            Self.logger.debug("EEP: Parsing - DocType: \(docType), DocNum: \(docNum), DOB: \(dob), Expiry: \(expiry)")
            
            // Validate document type
            if docType != "CS" {
                Self.logger.debug("EEP: Invalid document type: \(docType)")
                return nil
            }
            
            // Validate check digits
            if !validateCheckDigit(docNum, docNumCheck) {
                Self.logger.debug("EEP: Invalid document number check digit")
                // Continue - might still be valid with OCR errors
            }
            
            if !validateCheckDigit(expiry, expiryCheck) {
                Self.logger.debug("EEP: Invalid expiry check digit")
            }
            
            if !validateCheckDigit(dob, dobCheck) {
                Self.logger.debug("EEP: Invalid DOB check digit")
            }
            
            // Validate final composite check digit
            let startIdx1 = mutableLine.index(mutableLine.startIndex, offsetBy: 2)
            let endIdx1 = mutableLine.index(mutableLine.startIndex, offsetBy: 12)
            let startIdx2 = mutableLine.index(mutableLine.startIndex, offsetBy: 13)
            let endIdx2 = mutableLine.index(mutableLine.startIndex, offsetBy: 20)
            let startIdx3 = mutableLine.index(mutableLine.startIndex, offsetBy: 21)
            let endIdx3 = mutableLine.index(mutableLine.startIndex, offsetBy: 28)
            
            let compositeData = String(mutableLine[startIdx1..<endIdx1]) +
                              String(mutableLine[startIdx2..<endIdx2]) +
                              String(mutableLine[startIdx3..<endIdx3])
            
            if !validateCheckDigit(compositeData, finalCheck) {
                Self.logger.debug("EEP: Invalid final composite check digit")
            }
            
            // Clean the extracted data
            var cleanDocNum = cleanMrzCharacters(docNum)
            var cleanDob = cleanMrzCharacters(dob)
            var cleanExpiry = cleanMrzCharacters(expiry)
            
            // Validate dates
            if !isValidDate(cleanDob) {
                Self.logger.debug("EEP: Invalid DOB date: \(cleanDob)")
                cleanDob = fixDateOcrErrors(cleanDob)
                if !isValidDate(cleanDob) {
                    return nil
                }
            }
            
            if !isValidDate(cleanExpiry) {
                Self.logger.debug("EEP: Invalid expiry date: \(cleanExpiry)")
                cleanExpiry = fixDateOcrErrors(cleanExpiry)
                if !isValidDate(cleanExpiry) {
                    return nil
                }
            }
            
            // Success! Create result dictionary
            let result: [String: String] = [
                "DOC_NUM": cleanDocNum,
                "DOB": cleanDob,
                "EXPIRY": cleanExpiry,
                "DOC_TYPE": "EEP"
            ]
            
            Self.logger.debug("EEP: Successfully parsed MRZ!")
            return result
            
        } catch {
            Self.logger.error("EEP: Error parsing MRZ line: \(error.localizedDescription)")
            return nil
        }
    }
    
    override func getDocumentType() -> String {
        return "HK/Macao Travel Permit (EEP)"
    }
}
