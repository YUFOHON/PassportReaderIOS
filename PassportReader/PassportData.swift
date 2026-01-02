import UIKit

struct PassportData {
    // SOD
    var hasValidSignature: Bool = false
    var signingCountry: String?
    var rawSODData: Data?
    var dataGroupHashes: [Int: Data]?
    
    // DG1 - MRZ
    var documentCode: String?
    var issuingState: String?
    var lastName: String?
    var firstName: String?
    var documentNumber: String?
    var nationality: String?
    var dateOfBirth: String?
    var gender: String?
    var dateOfExpiry: String?
    var optionalData1: String?
    
    // DG2 - Face
    var faceImages: [UIImage]?
    var faceImageMimeTypes: [String]?
    
    // DG3 - Fingerprints
    var fingerprints: [FingerData]?
    var hasFingerprintData: Bool = false
    
    // DG4 - Iris
    var irisScans: [IrisData]?
    var hasIrisData: Bool = false
    
    // DG11 - Additional Personal Details
    var fullName: String?
    var personalNumber: String?
    var placeOfBirth: [String]?
    var address: [String]?
    var telephone: String?
    var profession: String?
    
    // DG12 - Document Details
    var issuingAuthority: String?
    var dateOfIssue: String?
    var endorsementsAndObservations: String?
    
    // DG14 - Security
    var hasChipAuthentication: Bool = false
    var hasActiveAuthentication: Bool = false
    var activeAuthenticationPerformed: Bool = false
    
    // Metadata
    var authenticationMethod: AuthMethod?
    var availableDataGroups: [Int]?
    var supportedSecurityProtocols: [String]?
}

struct FingerData {
    var fingerImage: UIImage?
    var position: Int?
    var imageFormat: String?
}

struct IrisData {
    var irisImage: UIImage?
    var eyeLabel: String?
    var imageFormat: String?
}

enum AuthMethod: String {
    case pace = "PACE"
    case bac = "BAC"
    case none = "None"
}
