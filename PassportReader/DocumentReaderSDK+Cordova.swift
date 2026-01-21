//
//  DocumentReaderSDK+Cordova.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 20/1/2026.
//

import Foundation
import UIKit
import PassportReaderFramework

// MARK: - Objective-C Compatible Types
@objc public enum OBDocumentType: Int {
    case unknown
    case passport
    case idCard
    case eep
    
    public var stringValue: String {
        switch self {
        case .passport: return "passport"
        case .idCard: return "idCard"
        case .eep: return "eep"
        case .unknown: return "unknown"
        }
    }
    
    public static func from(_ documentType: DocumentType) -> OBDocumentType {
        switch documentType {
        case .passport: return .passport
        case .idCard: return .idCard
        case .eep: return .eep
        case .unknown: return .unknown
        }
    }
}

@objc public class OBMrzResult: NSObject {
    @objc public let documentNumber: String
    @objc public let dateOfBirth: String
    @objc public let dateOfExpiry: String
    @objc public let documentType: OBDocumentType
    @objc public let mrzLines: Int
    
    @objc public init(documentNumber: String, dateOfBirth: String, dateOfExpiry: String, documentType: OBDocumentType, mrzLines: Int) {
        self.documentNumber = documentNumber
        self.dateOfBirth = dateOfBirth
        self.dateOfExpiry = dateOfExpiry
        self.documentType = documentType
        self.mrzLines = mrzLines
    }
    
    public convenience init(from mrzResult: MrzResult) {
        self.init(
            documentNumber: mrzResult.documentNumber,
            dateOfBirth: mrzResult.dateOfBirth,
            dateOfExpiry: mrzResult.dateOfExpiry,
            documentType: OBDocumentType.from(mrzResult.documentType),
            mrzLines: mrzResult.mrzLines
        )
    }
}

@objc public class OBDocumentData: NSObject {
    @objc public let documentType: OBDocumentType
    @objc public let documentNumber: String?
    @objc public let firstName: String?
    @objc public let lastName: String?
    @objc public let dateOfBirth: String?
    @objc public let dateOfExpiry: String?
    @objc public let nationality: String?
    @objc public let issuingCountry: String?
    @objc public let gender: String?
    @objc public let faceImage: UIImage?
    @objc public let rawData: [String: Any]?
    
    @objc public init(documentType: OBDocumentType,
                     documentNumber: String?,
                     firstName: String?,
                     lastName: String?,
                     dateOfBirth: String?,
                     dateOfExpiry: String?,
                     nationality: String?,
                     issuingCountry: String?,
                     gender: String?,
                     faceImage: UIImage?,
                     rawData: [String: Any]?) {
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
    
    public convenience init(from documentData: DocumentData) {
        self.init(
            documentType: OBDocumentType.from(documentData.documentType),
            documentNumber: documentData.documentNumber,
            firstName: documentData.firstName,
            lastName: documentData.lastName,
            dateOfBirth: documentData.dateOfBirth,
            dateOfExpiry: documentData.dateOfExpiry,
            nationality: documentData.nationality,
            issuingCountry: documentData.issuingCountry,
            gender: documentData.gender,
            faceImage: documentData.faceImage,
            rawData: documentData.rawData
        )
    }
}
