//
//  ScanOverlayView.swift
//  PassportReader
//
//  Created by Fo Hon Yu on 14/1/2026.
//

import Foundation
import UIKit

class ScanOverlayView: UIView {
    
    // MARK: - UI Components
    
    let scanRegionView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.shadowColor = .black
        label.shadowOffset = CGSize(width: 0, height: 1)
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .systemGreen
        progress.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.layer.cornerRadius = 2
        progress.clipsToBounds = true
        return progress
    }()
    
    private let cornerViews: [UIView] = {
        return (0..<4).map { _ in
            let view = UIView()
            view.backgroundColor = .systemGreen
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        return button
    }()
    
    private let flashButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        return button
    }()
    
    // MARK: - Properties
    
    var instructionText: String = "" {
        didSet {
            instructionLabel.text = instructionText
        }
    }
    
    var onClose: (() -> Void)?
    var onFlashToggle: (() -> Void)?
    
    private var isFlashOn = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .clear
        
        // Add scan region
        addSubview(scanRegionView)
        
        // Add corners
        cornerViews.forEach { addSubview($0) }
        
        // Add instruction label
        addSubview(instructionLabel)
        
        // Add progress view
        addSubview(progressView)
        
        // Add buttons
        addSubview(closeButton)
        addSubview(flashButton)
        
        setupConstraints()
        setupCorners()
        setupButtons()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scan region - centered with passport-like aspect ratio
            scanRegionView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -50),
            scanRegionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            scanRegionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            scanRegionView.heightAnchor.constraint(equalToConstant: 200),
            
            // Instruction label
            instructionLabel.topAnchor.constraint(equalTo: scanRegionView.bottomAnchor, constant: 40),
            instructionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 60),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -60),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Close button
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Flash button
            flashButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            flashButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupCorners() {
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4
        
        // Top-left corner (horizontal)
        let topLeftH = UIView()
        topLeftH.backgroundColor = .systemGreen
        topLeftH.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topLeftH)
        
        // Top-left corner (vertical)
        let topLeftV = UIView()
        topLeftV.backgroundColor = .systemGreen
        topLeftV.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topLeftV)
        
        // Top-right corner (horizontal)
        let topRightH = UIView()
        topRightH.backgroundColor = .systemGreen
        topRightH.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topRightH)
        
        // Top-right corner (vertical)
        let topRightV = UIView()
        topRightV.backgroundColor = .systemGreen
        topRightV.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topRightV)
        
        // Bottom-left corner (horizontal)
        let bottomLeftH = UIView()
        bottomLeftH.backgroundColor = .systemGreen
        bottomLeftH.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomLeftH)
        
        // Bottom-left corner (vertical)
        let bottomLeftV = UIView()
        bottomLeftV.backgroundColor = .systemGreen
        bottomLeftV.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomLeftV)
        
        // Bottom-right corner (horizontal)
        let bottomRightH = UIView()
        bottomRightH.backgroundColor = .systemGreen
        bottomRightH.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomRightH)
        
        // Bottom-right corner (vertical)
        let bottomRightV = UIView()
        bottomRightV.backgroundColor = .systemGreen
        bottomRightV.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomRightV)
        
        NSLayoutConstraint.activate([
            // Top-left
            topLeftH.topAnchor.constraint(equalTo: scanRegionView.topAnchor),
            topLeftH.leadingAnchor.constraint(equalTo: scanRegionView.leadingAnchor),
            topLeftH.widthAnchor.constraint(equalToConstant: cornerLength),
            topLeftH.heightAnchor.constraint(equalToConstant: cornerWidth),
            
            topLeftV.topAnchor.constraint(equalTo: scanRegionView.topAnchor),
            topLeftV.leadingAnchor.constraint(equalTo: scanRegionView.leadingAnchor),
            topLeftV.widthAnchor.constraint(equalToConstant: cornerWidth),
            topLeftV.heightAnchor.constraint(equalToConstant: cornerLength),
            
            // Top-right
            topRightH.topAnchor.constraint(equalTo: scanRegionView.topAnchor),
            topRightH.trailingAnchor.constraint(equalTo: scanRegionView.trailingAnchor),
            topRightH.widthAnchor.constraint(equalToConstant: cornerLength),
            topRightH.heightAnchor.constraint(equalToConstant: cornerWidth),
            
            topRightV.topAnchor.constraint(equalTo: scanRegionView.topAnchor),
            topRightV.trailingAnchor.constraint(equalTo: scanRegionView.trailingAnchor),
            topRightV.widthAnchor.constraint(equalToConstant: cornerWidth),
            topRightV.heightAnchor.constraint(equalToConstant: cornerLength),
            
            // Bottom-left
            bottomLeftH.bottomAnchor.constraint(equalTo: scanRegionView.bottomAnchor),
            bottomLeftH.leadingAnchor.constraint(equalTo: scanRegionView.leadingAnchor),
            bottomLeftH.widthAnchor.constraint(equalToConstant: cornerLength),
            bottomLeftH.heightAnchor.constraint(equalToConstant: cornerWidth),
            
            bottomLeftV.bottomAnchor.constraint(equalTo: scanRegionView.bottomAnchor),
            bottomLeftV.leadingAnchor.constraint(equalTo: scanRegionView.leadingAnchor),
            bottomLeftV.widthAnchor.constraint(equalToConstant: cornerWidth),
            bottomLeftV.heightAnchor.constraint(equalToConstant: cornerLength),
            
            // Bottom-right
            bottomRightH.bottomAnchor.constraint(equalTo: scanRegionView.bottomAnchor),
            bottomRightH.trailingAnchor.constraint(equalTo: scanRegionView.trailingAnchor),
            bottomRightH.widthAnchor.constraint(equalToConstant: cornerLength),
            bottomRightH.heightAnchor.constraint(equalToConstant: cornerWidth),
            
            bottomRightV.bottomAnchor.constraint(equalTo: scanRegionView.bottomAnchor),
            bottomRightV.trailingAnchor.constraint(equalTo: scanRegionView.trailingAnchor),
            bottomRightV.widthAnchor.constraint(equalToConstant: cornerWidth),
            bottomRightV.heightAnchor.constraint(equalToConstant: cornerLength)
        ])
    }
    
    private func setupButtons() {
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        onClose?()
    }
    
    @objc private func flashButtonTapped() {
        isFlashOn.toggle()
        let imageName = isFlashOn ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(UIImage(systemName: imageName), for: .normal)
        onFlashToggle?()
    }
    
    // MARK: - Public Methods
    
    func updateProgress(_ progress: Float) {
        UIView.animate(withDuration: 0.2) {
            self.progressView.setProgress(progress, animated: true)
        }
    }
    
    func showSuccess() {
        UIView.animate(withDuration: 0.3) {
            self.scanRegionView.layer.borderColor = UIColor.systemGreen.cgColor
            self.instructionLabel.textColor = .systemGreen
            self.progressView.setProgress(1.0, animated: true)
        }
        
        // Add checkmark animation
        addCheckmarkAnimation()
    }
    
    func showError() {
        UIView.animate(withDuration: 0.3, animations: {
            self.scanRegionView.layer.borderColor = UIColor.systemRed.cgColor
            self.instructionLabel.textColor = .systemRed
        }) { _ in
            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.reset()
            }
        }
        
        // Shake animation
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.timingFunction = CAMediaTimingFunction(name: .linear)
        shake.values = [-10, 10, -10, 10, -5, 5, -2, 2, 0]
        shake.duration = 0.6
        scanRegionView.layer.add(shake, forKey: "shake")
    }
    
    func reset() {
        UIView.animate(withDuration: 0.3) {
            self.scanRegionView.layer.borderColor = UIColor.white.cgColor
            self.instructionLabel.textColor = .white
            self.progressView.setProgress(0, animated: false)
        }
        instructionLabel.text = "Position passport in frame"
    }
    
    func setFlashEnabled(_ enabled: Bool) {
        flashButton.isEnabled = enabled
        flashButton.alpha = enabled ? 1.0 : 0.5
    }
    
    // MARK: - Animations
    
    private func addCheckmarkAnimation() {
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmark.tintColor = .systemGreen
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.alpha = 0
        checkmark.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        addSubview(checkmark)
        
        NSLayoutConstraint.activate([
            checkmark.centerXAnchor.constraint(equalTo: scanRegionView.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: scanRegionView.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 80),
            checkmark.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: .curveEaseOut, animations: {
            checkmark.alpha = 1
            checkmark.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseIn, animations: {
                checkmark.alpha = 0
                checkmark.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { _ in
                checkmark.removeFromSuperview()
            }
        }
    }
    
    func startScanningAnimation() {
        // Animated scanning line
        let scanLine = UIView()
        scanLine.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.5)
        scanLine.translatesAutoresizingMaskIntoConstraints = false
        scanRegionView.addSubview(scanLine)
        
        NSLayoutConstraint.activate([
            scanLine.leadingAnchor.constraint(equalTo: scanRegionView.leadingAnchor),
            scanLine.trailingAnchor.constraint(equalTo: scanRegionView.trailingAnchor),
            scanLine.heightAnchor.constraint(equalToConstant: 2),
            scanLine.topAnchor.constraint(equalTo: scanRegionView.topAnchor)
        ])
        
        // Animate
        UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse], animations: {
            scanLine.transform = CGAffineTransform(translationX: 0, y: self.scanRegionView.bounds.height)
        })
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Create dimming effect with cutout for scan region
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Fill entire view with semi-transparent black
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
        
        // Cut out the scan region
        context.setBlendMode(.destinationOut)
        let scanPath = UIBezierPath(roundedRect: scanRegionView.frame, cornerRadius: 8)
        context.addPath(scanPath.cgPath)
        context.fillPath()
    }
}

// MARK: - Convenience Methods

extension ScanOverlayView {
    
    func showMessage(_ message: String, duration: TimeInterval = 2.0) {
        instructionLabel.text = message
        
        UIView.animate(withDuration: 0.3, animations: {
            self.instructionLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: [], animations: {
                self.instructionLabel.alpha = 0.0
            }) { _ in
                self.instructionLabel.alpha = 1.0
            }
        }
    }
    
    func pulseAnimation() {
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
            self.scanRegionView.layer.borderColor = UIColor.systemGreen.cgColor
            self.scanRegionView.layer.borderWidth = 3
        }) { _ in
            self.scanRegionView.layer.borderColor = UIColor.white.cgColor
            self.scanRegionView.layer.borderWidth = 2
        }
    }
}
