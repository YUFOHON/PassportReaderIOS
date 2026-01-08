//
//  MrzParser.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 7/1/2026.
//

import Foundation

protocol MrzParser {
    /// Check if this parser can handle the given line
    func canParse(_ line: String) -> Bool
    
    /// Parse the MRZ line and return the extracted data
    /// - Returns: Dictionary with extracted data, or nil if parsing failed
    func parse(_ line: String) -> [String: String]?
    
    /// Get the document type this parser handles
    func getDocumentType() -> String
}
