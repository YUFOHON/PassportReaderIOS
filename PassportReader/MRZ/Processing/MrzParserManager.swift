

import Foundation

class MrzParserManager {
    
    private let cleaner = MRZCleaner()
    private let validator = MRZValidator()
    private let extractor = MRZExtractor()
    
    // MARK: - Main Parsing Entry Point
    
    func parseMRZ(lines: [String]) -> MRZResult? {
        // Create candidates with dummy positions
        let candidates = lines.enumerated().map { (index, text) in
            (text: text, y: CGFloat(lines.count - index), confidence: Float(0.9))
        }
        
        // Extract and identify document type
        guard let extracted = extractor.extractMRZ(from: candidates, cleaner: cleaner, validator: validator) else {
            // Fallback: try direct parsing
            return tryDirectParsing(lines: lines)
        }

        return parseByDocumentType(lines: extracted.lines, documentType: extracted.documentType)
    }
    
    // MARK: - Parse by Document Type
    
    private func parseByDocumentType(lines: [String], documentType: MRZDocumentType) -> MRZResult? {

        switch documentType {
        case .td3:
            return parseTD3(lines: lines)
        case .td1:
            return parseTD1(lines: lines)
        case .td2:
            return parseTD2(lines: lines)
        case .eepChina:
            return parseEEP(lines: lines)
        case .mrva:
            return parseMRVA(lines: lines)
        case .mrvb:
            return parseMRVB(lines: lines)
        }
    }
    
    // MARK: - Direct Parsing Fallback
    
    private func tryDirectParsing(lines: [String]) -> MRZResult? {
        let cleanedLines = lines.map { cleaner.cleanMRZLine($0) }
        
        // Check for EEP (single line starting with CS)
        for line in cleanedLines {
            if validator.isEEPLine(line) {
                
                let a = parseEEP(lines: [line])
                return a
            }
        }
        
        // Try TD3 (passport)
        if let td3Lines = findTD3Lines(in: cleanedLines) {
            return parseTD3(lines: td3Lines)
        }
        
        // Try TD1 (ID card)
        if let td1Lines = findTD1Lines(in: cleanedLines) {
            return parseTD1(lines: td1Lines)
        }
        
        // Try TD2
        if let td2Lines = findTD2Lines(in: cleanedLines) {
            return parseTD2(lines: td2Lines)
        }
        
        return nil
    }
    
    // MARK: - EEP Parsing (往來港澳通行證)
    
    private func parseEEP(lines: [String]) -> MRZResult? {

        guard !lines.isEmpty else { return nil }
        
        let line = cleaner.cleanAndNormalizeEEP(lines[0])
        guard line.count >= 30 else { return nil }

        // EEP Structure (30 chars) - 2014版往來港澳通行證:
        // Pos 0-1: CS (document type identifier)
        // Pos 2-10: Document number (9 chars: C + digit/letter + 7 digits)
        // Pos 11: Check digit for document number
        // Pos 12: Filler (<)
        // Pos 13-18: Expiry date (YYMMDD)
        // Pos 19: Check digit for expiry
        // Pos 20: Filler (<)
        // Pos 21-26: Date of birth (YYMMDD)
        // Pos 27: Check digit for DOB
        // Pos 28: Filler (<)
        // Pos 29: Final check digit (overall check)
        
        let documentTypeCode = extractField(from: line, start: 0, length: 2)
        let documentNumber = extractField(from: line, start: 2, length: 9)
        let expiryDate = extractField(from: line, start: 13, length: 6)
        let dateOfBirth = extractField(from: line, start: 21, length: 6)
        
        // EEP is specifically for China mainland residents traveling to HK/Macau
        let nationality = "CHN"
        let countryCode = "CHN"
        
        return MRZResult(
            documentType: "EEP (往來港澳通行證)",
            documentTypeCode: .eepChina,
            countryCode: countryCode,
            surname: "",  // Not in EEP MRZ
            givenNames: "", // Not in EEP MRZ
            documentNumber: cleanDocumentNumber(documentNumber),
            nationality: nationality,
            dateOfBirth: dateOfBirth,
            sex: "", // Not in EEP MRZ
            expiryDate: expiryDate,
            personalNumber: nil,
            rawMRZ: [line]
        )
    }
    
    // MARK: - TD3 Parsing (Passport)
    
    private func parseTD3(lines: [String]) -> MRZResult? {
        guard lines.count >= 2 else { return nil }
        
        let line1 = cleaner.normalizeMRZLineLength(cleaner.cleanMRZLine(lines[0]), targetLength: 44)
        let line2 = cleaner.normalizeMRZLineLength(cleaner.cleanMRZLine(lines[1]), targetLength: 44)
        
        guard line1.count >= 44, line2.count >= 44 else { return nil }
        
        // Line 1 structure:
        // Pos 0-1: Document type (P<)
        // Pos 2-4: Issuing country
        // Pos 5-43: Names (surname<<given names)
        
        let documentType = String(line1.prefix(1))
        let countryCode = extractField(from: line1, start: 2, length: 3)
        let namesField = extractField(from: line1, start: 5, length: 39)
        let (surname, givenNames) = parseNames(namesField)
        
        // Line 2 structure:
        // Pos 0-8: Document number
        // Pos 9: Check digit
        // Pos 10-12: Nationality
        // Pos 13-18: Date of birth (YYMMDD)
        // Pos 19: Check digit
        // Pos 20: Sex
        // Pos 21-26: Expiry date (YYMMDD)
        // Pos 27: Check digit
        // Pos 28-42: Personal number + check digit
        
        let documentNumber = extractField(from: line2, start: 0, length: 9)
        let nationality = extractField(from: line2, start: 10, length: 3)
        let dateOfBirth = extractField(from: line2, start: 13, length: 6)
        let sex = extractField(from: line2, start: 20, length: 1)
        let expiryDate = extractField(from: line2, start: 21, length: 6)
        let personalNumber = extractField(from: line2, start: 28, length: 14)
        
        return MRZResult(
            documentType: "Passport (TD3)",
            documentTypeCode: .td3,
            countryCode: countryCode,
            surname: surname,
            givenNames: givenNames,
            documentNumber: cleanDocumentNumber(documentNumber),
            nationality: nationality,
            dateOfBirth: dateOfBirth,
            sex: parseSex(sex),
            expiryDate: expiryDate,
            personalNumber: personalNumber.isEmpty ? nil : personalNumber,
            rawMRZ: [line1, line2]
        )
    }
    
    // MARK: - TD1 Parsing (ID Card)
    
    private func parseTD1(lines: [String]) -> MRZResult? {
        guard lines.count >= 3 else { return nil }
        
        let line1 = cleaner.normalizeMRZLineLength(cleaner.cleanMRZLine(lines[0]), targetLength: 30)
        let line2 = cleaner.normalizeMRZLineLength(cleaner.cleanMRZLine(lines[1]), targetLength: 30)
        let line3 = cleaner.normalizeMRZLineLength(cleaner.cleanMRZLine(lines[2]), targetLength: 30)
        
        guard line1.count >= 30, line2.count >= 30, line3.count >= 30 else { return nil }
        
        // Line 1:
        // Pos 0-1: Document type
        // Pos 2-4: Issuing country
        // Pos 5-14: Document number
        // Pos 15: Check digit
        // Pos 16-29: Optional data
        
        let documentType = String(line1.prefix(1))
        let countryCode = extractField(from: line1, start: 2, length: 3)
        let documentNumber = extractField(from: line1, start: 5, length: 9)
        
        // Line 2:
        // Pos 0-5: Date of birth
        // Pos 6: Check digit
        // Pos 7: Sex
        // Pos 8-13: Expiry date
        // Pos 14: Check digit
        // Pos 15-17: Nationality
        // Pos 18-29: Optional data
        
        let dateOfBirth = extractField(from: line2, start: 0, length: 6)
        let sex = extractField(from: line2, start: 7, length: 1)
        let expiryDate = extractField(from: line2, start: 8, length: 6)
        let nationality = extractField(from: line2, start: 15, length: 3)
        
        // Line 3: Names (surname<<given names)
        let (surname, givenNames) = parseNames(line3)
        
        return MRZResult(
            documentType: "ID Card (TD1)",
            documentTypeCode: .td1,
            countryCode: countryCode,
            surname: surname,
            givenNames: givenNames,
            documentNumber: cleanDocumentNumber(documentNumber),
            nationality: nationality,
            dateOfBirth: dateOfBirth,
            sex: parseSex(sex),
            expiryDate: expiryDate,
            personalNumber: nil,
            rawMRZ: [line1, line2, line3]
        )
    }
    
    // MARK: - TD2 Parsing
    
    private func parseTD2(lines: [String]) -> MRZResult? {
        guard lines.count >= 2 else { return nil }
        
        let line1 = cleaner.normalizeMRZLineLength(cleaner.cleanMRZLine(lines[0]), targetLength: 36)
        let line2 = cleaner.normalizeMRZLineLength(cleaner.cleanMRZLine(lines[1]), targetLength: 36)
        
        guard line1.count >= 36, line2.count >= 36 else { return nil }
        
        // Line 1:
        // Pos 0-1: Document type
        // Pos 2-4: Issuing country
        // Pos 5-35: Names
        
        let documentType = String(line1.prefix(1))
        let countryCode = extractField(from: line1, start: 2, length: 3)
        let namesField = extractField(from: line1, start: 5, length: 31)
        let (surname, givenNames) = parseNames(namesField)
        
        // Line 2:
        // Pos 0-8: Document number
        // Pos 9: Check digit
        // Pos 10-12: Nationality
        // Pos 13-18: Date of birth
        // Pos 19: Check digit
        // Pos 20: Sex
        // Pos 21-26: Expiry date
        // Pos 27: Check digit
        // Pos 28-35: Optional data
        
        let documentNumber = extractField(from: line2, start: 0, length: 9)
        let nationality = extractField(from: line2, start: 10, length: 3)
        let dateOfBirth = extractField(from: line2, start: 13, length: 6)
        let sex = extractField(from: line2, start: 20, length: 1)
        let expiryDate = extractField(from: line2, start: 21, length: 6)
        
        return MRZResult(
            documentType: "Travel Document (TD2)",
            documentTypeCode: .td2,
            countryCode: countryCode,
            surname: surname,
            givenNames: givenNames,
            documentNumber: cleanDocumentNumber(documentNumber),
            nationality: nationality,
            dateOfBirth: dateOfBirth,
            sex: parseSex(sex),
            expiryDate: expiryDate,
            personalNumber: nil,
            rawMRZ: [line1, line2]
        )
    }
    
    // MARK: - Visa Parsing
    
    private func parseMRVA(lines: [String]) -> MRZResult? {
        // MRV-A has same structure as TD3
        guard let result = parseTD3(lines: lines) else { return nil }
        
        return MRZResult(
            documentType: "Visa Type A (MRV-A)",
            documentTypeCode: .mrva,
            countryCode: result.countryCode,
            surname: result.surname,
            givenNames: result.givenNames,
            documentNumber: result.documentNumber,
            nationality: result.nationality,
            dateOfBirth: result.dateOfBirth,
            sex: result.sex,
            expiryDate: result.expiryDate,
            personalNumber: result.personalNumber,
            rawMRZ: result.rawMRZ
        )
    }
    
    private func parseMRVB(lines: [String]) -> MRZResult? {
        // MRV-B has same structure as TD2
        guard let result = parseTD2(lines: lines) else { return nil }
        
        return MRZResult(
            documentType: "Visa Type B (MRV-B)",
            documentTypeCode: .mrvb,
            countryCode: result.countryCode,
            surname: result.surname,
            givenNames: result.givenNames,
            documentNumber: result.documentNumber,
            nationality: result.nationality,
            dateOfBirth: result.dateOfBirth,
            sex: result.sex,
            expiryDate: result.expiryDate,
            personalNumber: result.personalNumber,
            rawMRZ: result.rawMRZ
        )
    }
    
    // MARK: - Line Finding Helpers
    
    private func findTD3Lines(in lines: [String]) -> [String]? {
        var candidateLines: [String] = []
        
        for line in lines {
            if line.count >= 42 && line.count <= 46 {
                let normalized = cleaner.normalizeMRZLineLength(line, targetLength: 44)
                candidateLines.append(normalized)
            }
        }
        
        if candidateLines.count >= 2 {
            for i in 0..<candidateLines.count - 1 {
                let line1 = candidateLines[i]
                if line1.hasPrefix("P") {
                    return [line1, candidateLines[i + 1]]
                }
            }
        }
        
        return nil
    }
    
    private func findTD1Lines(in lines: [String]) -> [String]? {
        var candidateLines: [String] = []
        
        for line in lines {
            if line.count >= 28 && line.count <= 32 {
                // Skip EEP lines
                if !validator.isEEPLine(line) {
                    let normalized = cleaner.normalizeMRZLineLength(line, targetLength: 30)
                    candidateLines.append(normalized)
                }
            }
        }
        
        if candidateLines.count >= 3 {
            for i in 0..<candidateLines.count - 2 {
                let line1 = candidateLines[i]
                if line1.hasPrefix("I") || line1.hasPrefix("A") || line1.hasPrefix("C") {
                    if !line1.hasPrefix("CS") {
                        return [line1, candidateLines[i + 1], candidateLines[i + 2]]
                    }
                }
            }
        }
        
        return nil
    }
    
    private func findTD2Lines(in lines: [String]) -> [String]? {
        var candidateLines: [String] = []
        
        for line in lines {
            if line.count >= 34 && line.count <= 38 {
                let normalized = cleaner.normalizeMRZLineLength(line, targetLength: 36)
                candidateLines.append(normalized)
            }
        }
        
        if candidateLines.count >= 2 {
            for i in 0..<candidateLines.count - 1 {
                let line1 = candidateLines[i]
                if line1.hasPrefix("P") || line1.hasPrefix("I") || line1.hasPrefix("A") || line1.hasPrefix("C") || line1.hasPrefix("V") {
                    return [line1, candidateLines[i + 1]]
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func extractField(from line: String, start: Int, length: Int) -> String {
        guard start >= 0, start < line.count else { return "" }
        
        let startIndex = line.index(line.startIndex, offsetBy: start)
        let endOffset = min(start + length, line.count)
        let endIndex = line.index(line.startIndex, offsetBy: endOffset)
        
        return String(line[startIndex..<endIndex])
    }
    
    private func parseNames(_ field: String) -> (surname: String, givenNames: String) {
        let components = field.components(separatedBy: "<<")
        
        let surname: String
        let givenNames: String
        
        if components.count >= 2 {
            surname = components[0].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)
            givenNames = components[1].replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)
        } else {
            surname = field.replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)
            givenNames = ""
        }
        
        return (surname.capitalized, givenNames.capitalized)
    }
    
    private func cleanDocumentNumber(_ number: String) -> String {
        return number.replacingOccurrences(of: "<", with: "").trimmingCharacters(in: .whitespaces)
    }
    
    private func parseSex(_ code: String) -> String {
        switch code.uppercased() {
        case "M": return "Male"
        case "F": return "Female"
        case "<", "X": return "Unspecified"
        default: return code
        }
    }
}
