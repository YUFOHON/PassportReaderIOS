//
//  MRZResult.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 16/1/2026.
//

import Foundation
import UIKit

class MRZGuidanceOverlay: UIView {
    
    // MARK: - Properties
    private(set) var guideBoxFrame: CGRect = .zero
    private var currentBorderColor: UIColor = .white
    private var detectedDocumentRect: CGRect?
    private var cornerRadius: CGFloat = 12
    private var borderWidth: CGFloat = 3
    private var maskAlpha: CGFloat = 0.6
    
    // Guide box sizing
    private let guideBoxWidthRatio: CGFloat = 0.88
    private let guideBoxAspectRatio: CGFloat = 1.42 // Default passport ratio
    
    // Corner indicators
    private var showCorners: Bool = true
    private let cornerLength: CGFloat = 30
    private let cornerLineWidth: CGFloat = 4
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        calculateGuideBoxFrame()
        setNeedsDisplay()
    }
    
    private func calculateGuideBoxFrame() {
        let width = bounds.width * guideBoxWidthRatio
        let height = width / guideBoxAspectRatio
        
        let x = (bounds.width - width) / 2
        let y = (bounds.height - height) / 2
        
        guideBoxFrame = CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw semi-transparent mask outside the guide box
        drawMask(context: context)
        
        // Draw guide box border
        drawGuideBorder(context: context)
        
        // Draw corner indicators
        if showCorners {
            drawCornerIndicators(context: context)
        }
        
        // Draw detected document overlay if available
        if let detectedRect = detectedDocumentRect {
            drawDetectedOverlay(context: context, rect: detectedRect)
        }
    }
    
    private func drawMask(context: CGContext) {
        // Fill entire view with semi-transparent black
        context.setFillColor(UIColor.black.withAlphaComponent(maskAlpha).cgColor)
        context.fill(bounds)
        
        // Clear the guide box area
        let path = UIBezierPath(roundedRect: guideBoxFrame, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.setBlendMode(.clear)
        context.fillPath()
        context.setBlendMode(.normal)
    }
    
    private func drawGuideBorder(context: CGContext) {
        let path = UIBezierPath(roundedRect: guideBoxFrame, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.setStrokeColor(currentBorderColor.cgColor)
        context.setLineWidth(borderWidth)
        context.strokePath()
    }
    
    private func drawCornerIndicators(context: CGContext) {
        context.setStrokeColor(currentBorderColor.cgColor)
        context.setLineWidth(cornerLineWidth)
        context.setLineCap(.round)
        
        let rect = guideBoxFrame
        let offset: CGFloat = 2
        
        // Top-left corner
        context.move(to: CGPoint(x: rect.minX - offset, y: rect.minY + cornerLength))
        context.addLine(to: CGPoint(x: rect.minX - offset, y: rect.minY - offset))
        context.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY - offset))
        
        // Top-right corner
        context.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY - offset))
        context.addLine(to: CGPoint(x: rect.maxX + offset, y: rect.minY - offset))
        context.addLine(to: CGPoint(x: rect.maxX + offset, y: rect.minY + cornerLength))
        
        // Bottom-left corner
        context.move(to: CGPoint(x: rect.minX - offset, y: rect.maxY - cornerLength))
        context.addLine(to: CGPoint(x: rect.minX - offset, y: rect.maxY + offset))
        context.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY + offset))
        
        // Bottom-right corner
        context.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY + offset))
        context.addLine(to: CGPoint(x: rect.maxX + offset, y: rect.maxY + offset))
        context.addLine(to: CGPoint(x: rect.maxX + offset, y: rect.maxY - cornerLength))
        
        context.strokePath()
    }
    
    private func drawDetectedOverlay(context: CGContext, rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        context.addPath(path.cgPath)
        context.setStrokeColor(UIColor.green.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(2)
        context.strokePath()
    }
    
    // MARK: - Public Methods
    func updateBorderColor(_ color: UIColor, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.currentBorderColor = color
                self.setNeedsDisplay()
            }
        } else {
            currentBorderColor = color
            setNeedsDisplay()
        }
    }
    
    func updateDetectedRect(_ rect: CGRect?) {
        detectedDocumentRect = rect
        setNeedsDisplay()
    }
    
    func showSuccessAnimation() {
        currentBorderColor = UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
        
        UIView.animate(withDuration: 0.15, animations: {
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.transform = .identity
            }
        }
        
        setNeedsDisplay()
    }
    
    func reset() {
        currentBorderColor = .white
        detectedDocumentRect = nil
        setNeedsDisplay()
    }
}
