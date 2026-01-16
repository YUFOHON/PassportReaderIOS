//
//  MRZInfo.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 14/1/2026.
//
import Foundation

struct MRZInfo {
    var documentCode: String?
    var issuingCountry: String = ""
    var surname: String = ""
    var givenNames: String = ""
    var documentNumber: String = ""
    var nationality: String = ""
    var dateOfBirth: String = ""
    var sex: String = ""
    var expiryDate: String = ""
    var personalNumber: String = ""
    
    func isValid() -> Bool {
        return !documentNumber.isEmpty &&
               !dateOfBirth.isEmpty &&
               !expiryDate.isEmpty &&
               !surname.isEmpty
    }
}
