import Foundation

struct MRZResult: CustomStringConvertible {
    let documentType: String
    let documentTypeCode: MRZDocumentType
    let countryCode: String
    let surname: String
    let givenNames: String
    let documentNumber: String
    let nationality: String
    let dateOfBirth: String
    let sex: String
    let expiryDate: String
    let personalNumber: String?
    let rawMRZ: [String]
    
    var fullName: String {
        let name = "\(givenNames) \(surname)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "—" : name
    }
    
    var formattedDateOfBirth: String {
        formatMRZDate(dateOfBirth)
    }
    
    var formattedExpiryDate: String {
        formatMRZDate(expiryDate)
    }

    /// ✅ This is your "toString"
    var description: String {
        """
        MRZResult:
        ├─ Document Type: \(documentType)
        ├─ Country Code: \(countryCode)
        ├─ Full Name: \(fullName)
        ├─ Document Number: \(documentNumber)
        ├─ Nationality: \(nationality)
        ├─ Date of Birth: \(formattedDateOfBirth)
        ├─ Sex: \(sex)
        ├─ Expiry Date: \(formattedExpiryDate)
        ├─ Personal Number: \(personalNumber ?? "—")
        └─ Raw MRZ:
        \(rawMRZ.joined(separator: "\n"))
        """
    }
    
    private func formatMRZDate(_ date: String) -> String {
        let cleanDate = date.replacingOccurrences(of: "<", with: "")
        guard cleanDate.count == 6 else { return "—" }
        
        // Validate that all characters are digits
        guard cleanDate.allSatisfy({ $0.isNumber }) else { return "—" }
        
        let year = String(cleanDate.prefix(2))
        let month = String(cleanDate.dropFirst(2).prefix(2))
        let day = String(cleanDate.suffix(2))
        
        // Validate month and day ranges
        guard let monthInt = Int(month), monthInt >= 1 && monthInt <= 12,
              let dayInt = Int(day), dayInt >= 1 && dayInt <= 31,
              let yearInt = Int(year) else {
            return "—"
        }
        
        // Use a more accurate cutoff year (current year + 10)
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentYearLastTwo = currentYear % 100
        let cutoffYear = (currentYearLastTwo + 10) % 100
        
        let century: String
        if yearInt <= cutoffYear {
            century = "20"
        } else {
            century = "19"
        }
        
        return "\(day)/\(month)/\(century)\(year)"
    }
    
    // Convenience initializer
    init(text: String, documentType: MRZDocumentType = .td3) {
        self.rawMRZ = text.components(separatedBy: "\n")
        self.documentTypeCode = documentType
        self.documentType = documentType.displayName
        self.countryCode = ""
        self.surname = ""
        self.givenNames = ""
        self.documentNumber = ""
        self.nationality = ""
        self.dateOfBirth = ""
        self.sex = ""
        self.expiryDate = ""
        self.personalNumber = nil
    }
    
    // Full initializer
    init(documentType: String,
         documentTypeCode: MRZDocumentType,
         countryCode: String,
         surname: String,
         givenNames: String,
         documentNumber: String,
         nationality: String,
         dateOfBirth: String,
         sex: String,
         expiryDate: String,
         personalNumber: String?,
         rawMRZ: [String]) {
        self.documentType = documentType
        self.documentTypeCode = documentTypeCode
        self.countryCode = countryCode
        self.surname = surname
        self.givenNames = givenNames
        self.documentNumber = documentNumber
        self.nationality = nationality
        self.dateOfBirth = dateOfBirth
        self.sex = sex
        self.expiryDate = expiryDate
        self.personalNumber = personalNumber
        self.rawMRZ = rawMRZ
    }
}
