//
//  Td3PassportParser.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 7/1/2026.
//

import Foundation

class Td3PassportParser: BaseMrzParser {
    
    override func canParse(_ line: String) -> Bool {
        // TD3 passports have 44 character MRZ line 2
        if line.count < 43 || line.count > 45 {
            return false
        }
        
        // Check for date patterns (YYMMDD appears at least twice)
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
            
            // Ensure line is exactly 44 characters
            if mutableLine.count < 44 {
                Self.logger.debug("TD3: Line too short: \(mutableLine.count)")
                return nil
            }
            
            // Truncate if slightly longer
            mutableLine = String(mutableLine.prefix(44))
            
            // TD3 Format Line 2 Structure
            let docNum = String(mutableLine.prefix(9))
            let docNumCheck = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 9)]
            let nationality = String(mutableLine.dropFirst(10).prefix(3))
            let dob = String(mutableLine.dropFirst(13).prefix(6))
            let dobCheck = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 19)]
            let sex = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 20)]
            let expiry = String(mutableLine.dropFirst(21).prefix(6))
            let expiryCheck = mutableLine[mutableLine.index(mutableLine.startIndex, offsetBy: 27)]
            
            Self.logger.debug("TD3: Parsing - DocNum: \(docNum), DOB: \(dob), Expiry: \(expiry)")
            
            // Validate check digits
            if !validateCheckDigit(docNum, docNumCheck) {
                Self.logger.debug("TD3: Invalid document number check digit")
                return nil
            }
            
            if !validateCheckDigit(dob, dobCheck) {
                Self.logger.debug("TD3: Invalid DOB check digit")
                return nil
            }
            
            if !validateCheckDigit(expiry, expiryCheck) {
                Self.logger.debug("TD3: Invalid expiry check digit")
                return nil
            }
            
            // Clean the extracted data
            var cleanDocNum = cleanMrzCharacters(docNum)
            var cleanDob = cleanMrzCharacters(dob)
            var cleanExpiry = cleanMrzCharacters(expiry)
            
            // Validate dates
            if !isValidDate(cleanDob) {
                Self.logger.debug("TD3: Invalid DOB date: \(cleanDob)")
                cleanDob = fixDateOcrErrors(cleanDob)
                if !isValidDate(cleanDob) {
                    return nil
                }
            }
            
            if !isValidDate(cleanExpiry) {
                Self.logger.debug("TD3: Invalid expiry date: \(cleanExpiry)")
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
                "NATIONALITY": nationality,
                "SEX": String(sex),
                "DOC_TYPE": "TD3_PASSPORT"
            ]
            
            Self.logger.debug("TD3: Successfully parsed MRZ!")
            return result
            
        } catch {
            Self.logger.error("TD3: Error parsing MRZ line: \(error.localizedDescription)")
            return nil
        }
    }
    
    override func getDocumentType() -> String {
        return "TD3 Passport"
    }
}
