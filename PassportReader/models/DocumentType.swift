//
//  DocumentType.swift
//  PassportReader
//

import UIKit

enum DocumentType: String, CaseIterable {
    case passport = "Passport"
    case idCard = "ID Card"
    case eep = "EEP (往來港澳通行證)"
    
    var aspectRatio: CGFloat {
        switch self {
        case .passport:
            // TD3 passport: 125mm x 88mm
            return 125.0 / 88.0
        case .idCard:
            // TD1 ID card: 85.6mm x 53.98mm (credit card size)
            return 85.6 / 53.98
        case .eep:
            // China EEP card: similar to ID card dimensions
            return 85.6 / 53.98
        }
    }
    
    var minAspectRatio: CGFloat {
        return aspectRatio * 0.80
    }
    
    var maxAspectRatio: CGFloat {
        return aspectRatio * 1.20
    }
    
    var displayColor: UIColor {
        switch self {
        case .passport:
            return UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0)
        case .idCard:
            return UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0)
        case .eep:
            return UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0)
        }
    }
    
    var lineCount: Int {
        switch self {
        case .passport:
            return 2
        case .idCard:
            return 3
        case .eep:
            return 1
        }
    }
    
    var lineLength: Int {
        switch self {
        case .passport:
            return 44
        case .idCard:
            return 30
        case .eep:
            return 30
        }
    }
    
    static func detect(from aspectRatio: CGFloat) -> DocumentType? {
        // For card-like documents (ID and EEP have same ratio)
        // We'll determine the exact type from MRZ content later
        for type in [DocumentType.passport, DocumentType.idCard] {
            if aspectRatio >= type.minAspectRatio && aspectRatio <= type.maxAspectRatio {
                return type
            }
        }
        return nil
    }
}

enum MRZDocumentType {
    case td1        // ID Card: 3 lines × 30 chars
    case td2        // Travel Document: 2 lines × 36 chars
    case td3        // Passport: 2 lines × 44 chars
    case mrva       // Visa Type A: 2 lines × 44 chars
    case mrvb       // Visa Type B: 2 lines × 36 chars
    case eepChina   // China EEP: 1 line × 30 chars
    
    var lineCount: Int {
        switch self {
        case .td1: return 3
        case .td2, .td3, .mrva, .mrvb: return 2
        case .eepChina: return 1
        }
    }
    
    var lineLength: Int {
        switch self {
        case .td1, .eepChina: return 30
        case .td2, .mrvb: return 36
        case .td3, .mrva: return 44
        }
    }
    
    var displayName: String {
        switch self {
        case .td1: return "ID Card (TD1)"
        case .td2: return "Travel Document (TD2)"
        case .td3: return "Passport (TD3)"
        case .mrva: return "Visa Type A"
        case .mrvb: return "Visa Type B"
        case .eepChina: return "EEP (往來港澳通行證)"
        }
    }
}
