import UIKit
import CoreNFC
import AVFoundation
import PassportReaderFramework

public struct MrzResult {
    public let documentNumber: String
    public let dateOfBirth: String
    public let dateOfExpiry: String
    public let documentType: DocumentType
    public let mrzLines: Int
}

public enum ErrorType: Error {
    case scanCancelled
    case nfcNotAvailable
    case nfcDisabled
    case nfcReadFailed(String)
    case invalidMRZ(String)
    case cameraPermissionDenied
    case authenticationFailed
    case connectionLost
}

// MARK: - Document Data Models
public struct DocumentData {
    
    public let documentType: DocumentType
    public let documentNumber: String?
    public let firstName: String?
    public let lastName: String?
    public let dateOfBirth: String?
    public let dateOfExpiry: String?
    public let nationality: String?
    public let issuingCountry: String?
    public let gender: String?
    public let faceImage: UIImage?
    public let rawData: [String: Any]
    
    public init(
        documentType: DocumentType,
        documentNumber: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        dateOfBirth: String? = nil,
        dateOfExpiry: String? = nil,
        nationality: String? = nil,
        issuingCountry: String? = nil,
        gender: String? = nil,
        faceImage: UIImage? = nil,
        rawData: [String: Any] = [:]
    ) {
        self.documentType = documentType
        self.documentNumber = documentNumber
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.dateOfExpiry = dateOfExpiry
        self.nationality = nationality
        self.issuingCountry = issuingCountry
        self.gender = gender
        self.faceImage = faceImage
        self.rawData = rawData
    }
}

// MARK: - Callback Protocol
public protocol DocumentReaderDelegate: AnyObject {
    func documentReader(_ reader: DocumentReaderSDK, didScanMRZ result: MrzResult)
    func documentReader(_ reader: DocumentReaderSDK, didUpdateProgress message: String, progress: Int)
    func documentReader(_ reader: DocumentReaderSDK, didReadDocument data: DocumentData)
    func documentReader(_ reader: DocumentReaderSDK, didFailWithError error: ErrorType)
}

// MARK: - Main SDK Class
public final class DocumentReaderSDK {
    
    // MARK: - Singleton
    public static let shared = DocumentReaderSDK()
    
    // MARK: - Properties
    private weak var delegate: DocumentReaderDelegate?
    private var viewModel = PassportReaderViewModel()
    private var currentDocumentType: DocumentType = .unknown
    
    // NFC Session
    private var nfcSession: NFCNDEFReaderSession?
    
    // Stored MRZ data
    private var documentNumber: String?
    private var dateOfBirth: String?
    private var dateOfExpiry: String?
    
    // MARK: - Configuration
    public func setDelegate(_ delegate: DocumentReaderDelegate) {
        self.delegate = delegate
    }
    
    public func isNFCAvailable() -> Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
    
    // MARK: - MRZ Scanning
    public func scanDocument(from viewController: UIViewController) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    let cameraVC = CameraViewController()
                    cameraVC.delegate = self
                    cameraVC.modalPresentationStyle = .fullScreen
                    viewController.present(cameraVC, animated: true)
                } else {
                    self?.delegate?.documentReader(self!, didFailWithError: .cameraPermissionDenied)
                }
            }
        }
    }
    
    // MARK: - NFC Reading
    public func startNfcReading() {
        // Check NFC availability
        guard isNFCAvailable() else {
            delegate?.documentReader(self, didFailWithError: .nfcNotAvailable)
            return
        }
        
        // Validate MRZ data
        guard let docNum = documentNumber,
              let dob = dateOfBirth,
              let expiry = dateOfExpiry else {
            delegate?.documentReader(self, didFailWithError: .invalidMRZ("Scan document first"))
            return
        }
        
        // Check document type
        guard currentDocumentType != .unknown else {
            delegate?.documentReader(self, didFailWithError: .invalidMRZ("Document type not specified"))
            return
        }
        
        // Start NFC session
        beginNfcRead(docNum: docNum, dob: dob, expiry: expiry)
    }
    
    public func stopNfcReading() {
        nfcSession?.invalidate()
        nfcSession = nil
    }
    
    // MARK: - Data Management
    public func setMrzData(documentNumber: String, dateOfBirth: String, dateOfExpiry: String, documentType: DocumentType) {
        self.documentNumber = documentNumber
        self.dateOfBirth = dateOfBirth
        self.dateOfExpiry = dateOfExpiry
        self.currentDocumentType = documentType
    }
    
    public func clearData() {
        documentNumber = nil
        dateOfBirth = nil
        dateOfExpiry = nil
        currentDocumentType = .unknown
    }
    
    // MARK: - Private Methods
    private func beginNfcRead(docNum: String, dob: String, expiry: String) {
        delegate?.documentReader(self, didUpdateProgress: "Starting NFC reading...", progress: 10)
        
        if currentDocumentType == .passport {
            readPassport(docNum: docNum, dob: dob, expiry: expiry)
        } else if currentDocumentType == .eep {
            readEEP(docNum: docNum, dob: dob, expiry: expiry)
        }
    }
    
    private func readPassport(docNum: String, dob: String, expiry: String) {
        delegate?.documentReader(self, didUpdateProgress: "Authenticating with passport...", progress: 30)
        
        viewModel.attemptPassportRead(docNum: docNum, dob: dob, expiry: expiry) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.handlePassportSuccess(data)
                case .failure(let error):
                    self?.handleNFCError(error)
                }
            }
        }
    }
    
    private func readEEP(docNum: String, dob: String, expiry: String) {
        delegate?.documentReader(self, didUpdateProgress: "Authenticating with EEP...", progress: 30)
        
        viewModel.attemptEEPRead(docNum: docNum, dob: dob, expiry: expiry) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.handleEEPSuccess(data)
                case .failure(let error):
                    self?.handleNFCError(error)
                }
            }
        }
    }
    
    private func handlePassportSuccess(_ data: PassportReader.PassportData) {
        // Convert to public DocumentData
        let documentData = convertPassportToDocumentData(data)
        delegate?.documentReader(self, didUpdateProgress: "Reading completed", progress: 100)
        delegate?.documentReader(self, didReadDocument: documentData)
    }
    
    private func handleEEPSuccess(_ data: EepDocumentReader.DocumentData) {
        // Convert to public DocumentData
        let documentData = convertEEPToDocumentData(data)
        delegate?.documentReader(self, didUpdateProgress: "Reading completed", progress: 100)
        delegate?.documentReader(self, didReadDocument: documentData)
    }
    
    private func handleNFCError(_ error: Error) {
        let errorMessage = error.localizedDescription
        
        if errorMessage.contains("Tag response error") ||
           errorMessage.contains("no response") ||
           errorMessage.contains("Tag Error") {
            delegate?.documentReader(self, didFailWithError: .connectionLost)
        } else if errorMessage.contains("InvalidMRZKey") || errorMessage.contains("BAC Failed") {
            delegate?.documentReader(self, didFailWithError: .authenticationFailed)
        } else {
            delegate?.documentReader(self, didFailWithError: .nfcReadFailed(errorMessage))
        }
    }
    
    // MARK: - Data Conversion
    private func convertPassportToDocumentData(_ data: PassportReader.PassportData) -> DocumentData {
        var rawData: [String: Any] = [:]
        
        // Basic info
        rawData["documentCode"] = data.documentCode
        rawData["issuingState"] = data.issuingState
        rawData["optionalData1"] = data.optionalData1
        rawData["optionalData2"] = data.optionalData2
        rawData["fullName"] = data.fullName
        rawData["personalNumber"] = data.personalNumber
        rawData["placeOfBirth"] = data.placeOfBirth
        rawData["address"] = data.address
        rawData["telephone"] = data.telephone
        rawData["profession"] = data.profession
        rawData["issuingAuthority"] = data.issuingAuthority
        rawData["dateOfIssue"] = data.dateOfIssue
        rawData["endorsementsAndObservations"] = data.endorsementsAndObservations
        rawData["authenticationMethod"] = data.authenticationMethod.rawValue
        rawData["hasChipAuthentication"] = data.hasChipAuthentication
        rawData["hasActiveAuthentication"] = data.hasActiveAuthentication
        rawData["dataGroupHashes"] = data.dataGroupHashes
        rawData["availableDataGroups"] = data.availableDataGroups
        
        return DocumentData(
            documentType: .passport,
            documentNumber: data.documentNumber,
            firstName: data.firstName,
            lastName: data.lastName,
            dateOfBirth: data.dateOfBirth?.description,
            dateOfExpiry: data.dateOfExpiry?.description,
            nationality: data.nationality,
            issuingCountry: data.issuingState,
            gender: data.gender,
            faceImage: data.faceImages.first,
            rawData: rawData
        )
    }
    
    private func convertEEPToDocumentData(_ data: EepDocumentReader.DocumentData) -> DocumentData {
        var rawData: [String: Any] = [:]
        
        // Basic info
        rawData["cardNumber"] = data.cardNumber
        rawData["issuingCountry"] = data.issuingCountry
        rawData["chineseName"] = data.chineseName
        rawData["pinyinName"] = data.pinyinName
        rawData["placeOfBirth"] = data.placeOfBirth
        rawData["personalNumber"] = data.personalNumber
        rawData["telephone"] = data.telephone
        rawData["profession"] = data.profession
        rawData["address"] = data.address
        rawData["issuingAuthority"] = data.issuingAuthority
        rawData["dateOfIssue"] = data.dateOfIssue
        rawData["endorsementsAndObservations"] = data.endorsementsAndObservations
        rawData["authenticationMethod"] = data.authenticationMethod
        rawData["hasChipAuthentication"] = data.hasChipAuthentication
        rawData["hasActiveAuthentication"] = data.hasActiveAuthentication
        rawData["checksumValid"] = data.checksumValid
        rawData["hasValidSignature"] = data.hasValidSignature
        rawData["dataGroupHashes"] = data.dataGroupHashes
        rawData["availableDataGroups"] = data.availableDataGroups
        rawData["sodPresent"] = data.sodPresent
        rawData["faceImageMimeTypes"] = data.faceImageMimeTypes
        
        // Parse Chinese name for first/last
        var firstName: String?
        var lastName: String?
        
        if let chineseName = data.chineseName {
            let components = chineseName.split(separator: " ")
            if components.count >= 2 {
                lastName = String(components[0])
                firstName = components.dropFirst().joined(separator: " ")
            }
        }
        
        return DocumentData(
            documentType: .eep,
            documentNumber: data.cardNumber,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: data.dateOfBirth,
            dateOfExpiry: data.dateOfExpiry,
            nationality: data.nationality,
            issuingCountry: data.issuingCountry,
            gender: data.gender,
            faceImage: data.faceImages.first,
            rawData: rawData
        )
    }
}

// MARK: - Camera Delegate Extension
extension DocumentReaderSDK: CameraViewControllerDelegate {
    public func cameraViewController(_ controller: CameraViewController, didScanMRZ data: [String: String]) {
        // Extract data
        documentNumber = data[Constants.EXTRA_DOC_NUM]
        dateOfBirth = data[Constants.EXTRA_DOB]
        dateOfExpiry = data[Constants.EXTRA_EXPIRY]
        
        // Determine document type
        if let docType = data[Constants.EXTRA_DOC_TYPE] {
            if docType.contains("EEP") || docType == "EE" {
                currentDocumentType = .eep
            } else if docType.contains("P") {
                currentDocumentType = .passport
            } else {
                currentDocumentType = .unknown
            }
        }
        
        // Create MRZ result
        let result = MrzResult(
            documentNumber: documentNumber ?? "",
            dateOfBirth: dateOfBirth ?? "",
            dateOfExpiry: dateOfExpiry ?? "",
            documentType: currentDocumentType,
            mrzLines: Int(data[Constants.EXTRA_MRZ_LINES] ?? "0") ?? 0
        )
        
        delegate?.documentReader(self, didScanMRZ: result)
    }
}

