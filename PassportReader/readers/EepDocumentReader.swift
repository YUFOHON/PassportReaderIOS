import Foundation
import UIKit
import NFCPassportReader

// MARK: - Main Reader Class

class EepDocumentReader {
    private static let TAG = "EepDocumentReader"
    
    // MARK: - Public Types
    
    enum DocumentType: String {
        case hongKongMacau = "HK_MACAU_PERMIT"
        case taiwan = "TAIWAN_PERMIT"
        case unknown = "UNKNOWN"
        
        static func from(code: String?) -> DocumentType {
            guard let code = code?.uppercased() else { return .unknown }
            switch code {
            case "CS", "C<": return .hongKongMacau
            case "CD": return .taiwan
            default: return .unknown
            }
        }
    }
    
    enum AuthMethod: String {
        case pace = "PACE", bac = "BAC", none = "NONE"
    }
    
    struct DocumentData {
        // Core identification
        var documentType: DocumentType = .unknown
        var documentCode: String?
        var documentNumber: String?
        var cardNumber: String?
        
        // Personal information
        var firstName: String?
        var lastName: String?
        var chineseName: String?
        var pinyinName: String?
        var fullName: String?
        var nationality: String?
        var gender: String?
        var dateOfBirth: String?
        var dateOfExpiry: String?
        var placeOfBirth: String?
        
        // Issuing information
        var issuingCountry: String?
        var issuingAuthority: String?
        var dateOfIssue: String?
        
        // Biometric & Security
        var faceImages: [UIImage] = []
        var faceImageMimeTypes: [String] = []
        var authenticationMethod: String?
        var availableDataGroups: [Int] = []
        var dataGroupHashes: [Int: String] = [:]
        
        // Validation
        var checksumValid: Bool = true
        var hasValidSignature: Bool = false
        var sodPresent: Bool = false
        
        // Optional data
        var personalNumber: String?
        var telephone: String?
        var profession: String?
        var address: String?
        var endorsementsAndObservations: String?
        var rawMrz: String?
        
        // Advanced security
        var hasChipAuthentication: Bool = false
        var hasActiveAuthentication: Bool = false
        var activeAuthPublicKey: String?
    }
    
    struct AuthData {
        let documentNumber: String
        let dateOfBirth: String
        let dateOfExpiry: String
        
        var isValid: Bool {
            !documentNumber.isEmpty && dateOfBirth.count >= 6 && dateOfExpiry.count >= 6
        }
        
        var mrzKey: String {
            // Clean and pad document number to 9 characters
            let cleanDoc = documentNumber
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
                .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
            
            let paddedDoc = cleanDoc.padding(toLength: 9, withPad: "<", startingAt: 0)
            let docCheckDigit = calculateCheckDigit(paddedDoc)
            
            // Normalize dates to YYMMDD
            let dob = normalizeDateYYMMDD(dateOfBirth)
            let dobCheckDigit = calculateCheckDigit(dob)
            
            let doe = normalizeDateYYMMDD(dateOfExpiry)
            let doeCheckDigit = calculateCheckDigit(doe)
            
            // Build MRZ key: doc(9) + docCheck(1) + dob(6) + dobCheck(1) + doe(6) + doeCheck(1)
            return "\(paddedDoc)\(docCheckDigit)\(dob)\(dobCheckDigit)\(doe)\(doeCheckDigit)"
        }
        
        private func normalizeDateYYMMDD(_ date: String) -> String {
            let digits = date.filter { $0.isNumber }
            
            // Handle different input formats
            if digits.count == 8 {
                // YYYYMMDD -> YYMMDD
                return String(digits.suffix(6))
            } else if digits.count == 6 {
                // Already YYMMDD
                return digits
            } else if digits.count == 10 {
                // YYYY-MM-DD with separators removed
                let cleaned = date.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                return String(cleaned.suffix(6))
            }
            
            // Pad if too short
            return digits.padding(toLength: 6, withPad: "0", startingAt: 0)
        }
        
        private func calculateCheckDigit(_ input: String) -> String {
            let weights = [7, 3, 1]
            var sum = 0
            
            for (index, char) in input.enumerated() {
                let value: Int
                if char.isNumber {
                    value = Int(String(char)) ?? 0
                } else if char >= "A" && char <= "Z" {
                    value = Int(char.asciiValue! - Character("A").asciiValue!) + 10
                } else if char == "<" {
                    value = 0
                } else {
                    value = 0
                }
                
                sum += value * weights[index % 3]
            }
            
            return String(sum % 10)
        }
    }
    
    // MARK: - Private Components
    
    private let mrzParser = EepReaderMrzParser()
    
    // MARK: - Public Interface
    
    func canRead(documentCode: String?) -> Bool {
        guard let code = documentCode?.uppercased() else { return false }
        return code == "CS" || code == "CD" || code.hasPrefix("C")
    }
    
    func readDocument(authData: AuthData, completion: @escaping (Result<DocumentData, Error>) -> Void) {
        guard authData.isValid else {
            completion(.failure(ReaderError.invalidAuthData))
            return
        }
        
        Task {
            do {
                let nfcReader = NFCPassportReader.PassportReader()
                print("📱 [\(Self.TAG)] Starting NFC read...")
                
                let passport = try await nfcReader.readPassport(
                    mrzKey: authData.mrzKey,
                    tags: [],
                    skipSecureElements: false,
                    customDisplayMessage: customDisplayMessage
                )
                
                let data = convertToDocumentData(passport)
                await MainActor.run { completion(.success(data)) }
            } catch {
                print("❌ [\(Self.TAG)] Read error: \(error)")
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Conversion
    
    private func convertToDocumentData(_ passport: NFCPassportModel) -> DocumentData {
        var data = DocumentData()
        
        // Authentication method
        data.authenticationMethod = passport.isPACESupported ? AuthMethod.pace.rawValue :
                                   passport.BACStatus == .success ? AuthMethod.bac.rawValue :
                                   AuthMethod.none.rawValue
        
        // Available data groups
        if let com = passport.getDataGroup(.COM) as? COM {
            data.availableDataGroups = com.dataGroupsPresent.compactMap { Int($0) }
        }
        
        // Read all data groups
        readSOD(passport, into: &data)
        readDG1(passport, into: &data)
        readDG2(passport, into: &data)
        readDG11(passport, into: &data)
        readDG12(passport, into: &data)
        readDG14(passport, into: &data)
        readDG15(passport, into: &data)
        
        // Finalize
        data.documentType = DocumentType.from(code: data.documentCode)
        data.fullName = data.chineseName?.isEmpty == false ? data.chineseName : data.pinyinName
        data.hasChipAuthentication = passport.chipAuthenticationStatus == .success
        data.hasActiveAuthentication = passport.activeAuthenticationPassed
        
        return data
    }
    
    // MARK: - Data Group Readers (Compact)
    
    private func readSOD(_ passport: NFCPassportModel, into data: inout DocumentData) {
        guard let sod = passport.getDataGroup(.SOD) else { return }
        
        data.sodPresent = true
        data.hasValidSignature = passport.passportCorrectlySigned
        
        for (dgId, hashInfo) in passport.dataGroupHashes {
            data.dataGroupHashes[dgIdToNumber(dgId)] = hashInfo.computedHash
        }
    }
    
    private func readDG1(_ passport: NFCPassportModel, into data: inout DocumentData) {
        guard let dg1 = passport.getDataGroup(.DG1) as? DataGroup1 else { return }
        
        let rawMrz = extractMrzFromDG1(dg1)
        data.rawMrz = rawMrz
        
        if mrzParser.isEepDocument(rawMrz) {
            let parsed = mrzParser.parse(rawMrz)
            applyParsedData(parsed, to: &data)
        } else {
            // Fallback to standard passport
            data.documentCode = passport.documentType
            data.issuingCountry = passport.issuingAuthority
            data.lastName = passport.lastName
            data.firstName = passport.firstName
            data.cardNumber = cleanCardNumber(passport.documentNumber)
            data.nationality = passport.nationality
            data.dateOfBirth = passport.dateOfBirth
            data.gender = passport.gender
            data.dateOfExpiry = passport.documentExpiryDate
        }
        
        data.pinyinName = buildFullName(data.firstName, data.lastName)
    }
    
    private func readDG2(_ passport: NFCPassportModel, into data: inout DocumentData) {
        guard passport.getDataGroup(.DG2) != nil, let image = passport.passportImage else { return }
        data.faceImages.append(image)
        data.faceImageMimeTypes.append("image/jpeg2000")
    }
    
    private func readDG11(_ passport: NFCPassportModel, into data: inout DocumentData) {
        guard let dg11 = passport.getDataGroup(.DG11) as? DataGroup11 else { return }
        
        if let fullName = dg11.fullName, ChineseNameDecoder.containsChinese(fullName) {
            data.chineseName = fullName
        }
        
//        data.personalNumber = dg11.personalNumber ?? passport.personalNumber
//        data.telephone = dg11.telephone ?? passport.phoneNumber
//        data.profession = dg11.profession
//        data.address = dg11.address ?? passport.residenceAddress
    }
    
    private func readDG12(_ passport: NFCPassportModel, into data: inout DocumentData) {
        guard let dg12 = passport.getDataGroup(.DG12) as? DataGroup12 else { return }
        
        data.issuingAuthority = dg12.issuingAuthority
        data.dateOfIssue = dg12.dateOfIssue
        data.endorsementsAndObservations = dg12.endorsementsOrObservations
    }
    
    private func readDG14(_ passport: NFCPassportModel, into data: inout DocumentData) {
        guard passport.getDataGroup(.DG14) != nil else { return }
        data.hasChipAuthentication = passport.isChipAuthenticationSupported
    }
    
    private func readDG15(_ passport: NFCPassportModel, into data: inout DocumentData) {
        guard let dg15 = passport.getDataGroup(.DG15) as? DataGroup15 else { return }
        
        data.hasActiveAuthentication = passport.activeAuthenticationSupported
        
        let publicKey = dg15.rsaPublicKey ?? dg15.ecdsaPublicKey
        if let key = publicKey, let keyData = OpenSSLUtils.getPublicKeyData(from: key) {
            data.activeAuthPublicKey = Data(keyData).base64EncodedString()
        }
    }
    
    // MARK: - Helpers
    
    private func extractMrzFromDG1(_ dg1: DataGroup1) -> String {
        if let mrzData = dg1.elements["5F1F"] {
            return mrzData
        }
        return dg1.body.map { String(format: "%c", $0) }.joined()
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func applyParsedData(_ parsed: EepReaderMrzParser.ParsedData, to data: inout DocumentData) {
        data.documentCode = parsed.documentCode
        data.cardNumber = cleanCardNumber(parsed.cardNumber)
        data.documentNumber = parsed.cardNumber
        data.issuingCountry = parsed.issuingState
        data.nationality = parsed.nationality
        data.dateOfBirth = parsed.dateOfBirth
        data.dateOfExpiry = parsed.dateOfExpiry
        data.gender = parsed.gender
        data.firstName = parsed.firstName
        data.lastName = parsed.lastName
        data.chineseName = parsed.chineseName
        data.placeOfBirth = parsed.placeOfBirth
        data.checksumValid = parsed.checksumValid
    }
    
    private func cleanCardNumber(_ number: String?) -> String? {
        number?.replacingOccurrences(of: "[< ]", with: "", options: .regularExpression)
               .trimmingCharacters(in: .whitespaces)
    }
    
    private func buildFullName(_ first: String?, _ last: String?) -> String? {
        let name = "\(first ?? "") \(last ?? "")".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
    
    private func dgIdToNumber(_ dgId: DataGroupId) -> Int {
        switch dgId {
        case .COM: return 0
        case .DG1: return 1
        case .DG2: return 2
        case .DG3: return 3
        case .DG4: return 4
        case .DG5: return 5
        case .DG6: return 6
        case .DG7: return 7
        case .DG8: return 8
        case .DG9: return 9
        case .DG10: return 10
        case .DG11: return 11
        case .DG12: return 12
        case .DG13: return 13
        case .DG14: return 14
        case .DG15: return 15
        case .DG16: return 16
        case .SOD: return 99
        default: return -1
        }
    }
    
    private func customDisplayMessage(_ msg: NFCViewDisplayMessage) -> String {
        switch msg {
        case .requestPresentPassport:
            return "Hold your iPhone near the permit"
        case .authenticatingWithPassport(let progress):
            return "Authenticating...\(progress)%"
        case .readingDataGroupProgress(let tag, let progress):
            return "\(tag.getName())... (\(progress)%)"
        case .successfulRead:
            return "✅ Success!"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - MRZ Parser with Field Length Constants

private struct EepReaderMrzParser {
    
    // MARK: - MRZ Field Length Constants
    
    private enum FieldLength {
        static let docCode = 1          // Document code (C)
        static let filler = 1           // Filler (<)
        static let documentNumber = 9   // Card number
        static let checkDigit = 1       // Check digit
        static let date = 6             // YYMMDD format
        static let chineseName = 12     // GBK encoded Chinese name
        static let englishName = 18     // English/Pinyin name
        static let gender = 1           // M/F
        static let obsolete = 1         // Obsolete field
        static let dobCentury = 1       // DOB century indicator
        static let thumbnailMod = 1     // Thumbnail modification flag
        static let thumbnailFlag = 1    // Thumbnail flag
        static let placeOfBirth = 3     // POB code
        
        // Combined field lengths for easier navigation
        static let docCodeWithFiller = docCode + filler                    // 2
        static let documentNumberBlock = documentNumber + checkDigit       // 10
        static let expiryBlock = filler + date + checkDigit + filler       // 9
        static let dobBlock = date + checkDigit + filler                   // 8
        static let overallCheck = checkDigit                               // 1
        static let obsoleteBlock = obsolete + obsolete + dobCentury +      // 5
                                   thumbnailMod + thumbnailMod
        static let thumbnailBlock = thumbnailFlag + thumbnailFlag          // 2
    }
    
    // MARK: - Parsed Data Structure
    
    struct ParsedData {
        var documentCode: String?
        var cardNumber: String?
        var issuingState: String?
        var nationality: String?
        var dateOfBirth: String?
        var dateOfExpiry: String?
        var gender: String?
        var firstName: String?
        var lastName: String?
        var chineseName: String?
        var placeOfBirth: String?
        var isValid: Bool = false
        var checksumValid: Bool = true
    }
    
    // MARK: - Public Methods
    
    func isEepDocument(_ mrz: String) -> Bool {
        let clean = mrz.replacingOccurrences(of: "[ \n\r]", with: "", options: .regularExpression)
        guard clean.count >= 2 else { return false }
        let code = String(clean.prefix(2)).uppercased()
        return code == "CS" || code == "CD"
    }
    
    func parse(_ mrz: String) -> ParsedData {
        var result = ParsedData()
        let normalized = normalizeMrz(mrz)
        
        guard normalized.count >= 90 else { return result }
        
        // Start parsing from position 0
        var idx = 0
        
        // Skip: doc code (1) + filler (1)
        idx += FieldLength.docCodeWithFiller
        
        // Extract: document number (9)
        result.cardNumber = substring(normalized, idx, FieldLength.documentNumber).trim()
        idx += FieldLength.documentNumberBlock  // +1 for check digit
        
        // Extract: expiry date (skip filler, read 6 digits)
        let expiry = substring(normalized, idx + FieldLength.filler, FieldLength.date).trim()
        result.dateOfExpiry = expiry
        idx += FieldLength.expiryBlock
        
        // Extract: date of birth (6) with century calculation
        let dob = calculateDOB(substring(normalized, idx, FieldLength.date).trim())
        result.dateOfBirth = dob
        idx += FieldLength.dobBlock
        
        // Skip: overall check digit
        idx += FieldLength.overallCheck
        
        // Extract: Chinese name (12 chars, GBK encoded)
        let chineseEncoded = substring(normalized, idx, FieldLength.chineseName)
        result.chineseName = ChineseNameDecoder.decode(mrzEncoded: chineseEncoded)
        idx += FieldLength.chineseName
        
        // Extract: English name (18 chars)
        let englishName = substring(normalized, idx, FieldLength.englishName)
        let (first, last) = parseEnglishName(englishName)
        result.firstName = first
        result.lastName = last
        idx += FieldLength.englishName
        
        // Extract: Gender (1)
        result.gender = substring(normalized, idx, FieldLength.gender).trim()
        idx += FieldLength.gender
        
        // Skip: obsolete fields (5)
        idx += FieldLength.obsoleteBlock
        
        // Skip: thumbnail flags (2)
        idx += FieldLength.thumbnailBlock
        
        // Extract: Place of birth (3)
        let pob = substring(normalized, idx, FieldLength.placeOfBirth)
            .trim()
            .replacingOccurrences(of: "<", with: " ")
        result.placeOfBirth = pob.isEmpty ? nil : pob
        
        // Set fixed values
        result.issuingState = "CHN"
        result.nationality = "CHN"
        result.isValid = true
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private func calculateDOB(_ yymmdd: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let today = formatter.string(from: Date())
        let century = String(today.prefix(2))
        
        var fullDate = century + yymmdd
        
        // If birth date is in future, subtract 1 from century
        if fullDate > today, let cent = Int(century) {
            fullDate = "\(cent - 1)" + yymmdd
        }
        
        return fullDate
    }
    
    private func parseEnglishName(_ field: String) -> (String?, String?) {
        let parts = field.trimmingCharacters(in: CharacterSet(charactersIn: "<"))
                        .components(separatedBy: "<")
                        .filter { !$0.isEmpty }
        
        if parts.count >= 2 { return (parts[1], parts[0]) }
        if parts.count == 1 { return (nil, parts[0]) }
        return (nil, nil)
    }
    
    private func normalizeMrz(_ mrz: String) -> String {
        var cleaned = mrz.replacingOccurrences(of: "[ \n\r]", with: "", options: .regularExpression)
        while cleaned.count < 90 { cleaned += "<" }
        return cleaned
    }
    
    private func substring(_ s: String, _ start: Int, _ length: Int) -> String {
        guard start >= 0, start + length <= s.count else { return "" }
        let startIdx = s.index(s.startIndex, offsetBy: start)
        let endIdx = s.index(startIdx, offsetBy: length)
        return String(s[startIdx..<endIdx])
    }
}

// MARK: - Chinese Name Decoder (Compact)

private struct ChineseNameDecoder {
    static func decode(mrzEncoded: String) -> String? {
        let cleaned = mrzEncoded.replacingOccurrences(of: "<", with: "")
        guard !cleaned.isEmpty else { return nil }
        
        let validLength = (cleaned.count / 4) * 4
        guard validLength > 0 else { return nil }
        
        let truncated = String(cleaned.prefix(validLength))
        
        // Convert MRZ chars to hex
        let hexString = truncated.uppercased().map { char -> String in
            let value: Int
            if char >= "A" && char <= "J" {
                value = Int(char.asciiValue! - Character("A").asciiValue!)
            } else if char >= "K" && char <= "P" {
                value = Int(char.asciiValue! - Character("K").asciiValue!) + 10
            } else {
                value = 0
            }
            return String(format: "%x", value)
        }.joined()
        
        // Hex to bytes
        guard let gbkBytes = hexToBytes(hexString) else { return nil }
        
        // Decode GBK
        return decodeGBK(gbkBytes)
    }
    
    static func containsChinese(_ string: String?) -> Bool {
        guard let string = string else { return false }
        return string.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }
    
    private static func hexToBytes(_ hex: String) -> [UInt8]? {
        var bytes = [UInt8]()
        var hexStr = hex.count % 2 != 0 ? "0" + hex : hex
        
        var idx = hexStr.startIndex
        while idx < hexStr.endIndex {
            let nextIdx = hexStr.index(idx, offsetBy: 2)
            guard let byte = UInt8(String(hexStr[idx..<nextIdx]), radix: 16) else { return nil }
            bytes.append(byte)
            idx = nextIdx
        }
        return bytes
    }
    
    private static func decodeGBK(_ bytes: [UInt8]) -> String? {
        let data = Data(bytes)
        let encodings = [
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue),
            CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)
        ]
        
        for encoding in encodings {
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(encoding)
            if let decoded = String(data: data, encoding: String.Encoding(rawValue: nsEncoding)) {
                return decoded
            }
        }
        return nil
    }
}

// MARK: - Error Type

enum ReaderError: LocalizedError {
    case invalidAuthData
    case authenticationFailed(String)
    case readFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAuthData: return "Invalid authentication data"
        case .authenticationFailed(let msg): return "Authentication failed: \(msg)"
        case .readFailed(let msg): return "Read failed: \(msg)"
        }
    }
}

// MARK: - String Extension

private extension String {
    func trim() -> String {
        trimmingCharacters(in: .whitespaces)
    }
}
