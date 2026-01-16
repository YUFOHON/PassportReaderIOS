//
//  BitmapUtils.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 14/1/2026.
//

import Foundation
import UIKit
import AVFoundation

class BitmapUtils {
    
//    static func cropToGuidanceOverlay(_ image: UIImage,
//                                     guidanceOverlay: MRZGuidanceOverlay,
//                                     previewView: UIView) -> UIImage? {
//        
//        // Get guidance box in preview coordinates
//        let guidanceRect = guidanceOverlay.getGuidanceBoxRect()
//        
//        print("🖼️  Cropping image:")
//        print("   ├─ Original size: \(image.size)")
//        print("   ├─ Guidance rect: \(guidanceRect)")
//        print("   └─ Preview size: \(previewView.bounds.size)")
//        
//        // Convert preview coordinates to image coordinates
//        let imageSize = image.size
//        let previewSize = previewView.bounds.size
//        
//        // Calculate scale factors
//        let scaleX = imageSize.width / previewSize.width
//        let scaleY = imageSize.height / previewSize.height
//        
//        // Apply scale to guidance rect
//        let cropRect = CGRect(
//            x: guidanceRect.origin.x * scaleX,
//            y: guidanceRect.origin.y * scaleY,
//            width: guidanceRect.width * scaleX,
//            height: guidanceRect.height * scaleY
//        )
//        
//        print("   └─ Crop rect: \(cropRect)")
//        
//        // Crop the image
//        guard let cgImage = image.cgImage,
//              let croppedCGImage = cgImage.cropping(to: cropRect) else {
//            print("❌ Failed to crop image")
//            return nil
//        }
//        
//        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
//        print("✅ Cropped to: \(croppedImage.size)")
//        
//        return croppedImage
//    }
    
    static func saveImageToFile(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return nil
        }
        
        let filename = "mrz_document_\(Date().timeIntervalSince1970).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            print("💾 Saved image: \(fileURL.path)")
            return fileURL.path
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }
}
