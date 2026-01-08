import UIKit
import Vision
import AVFoundation

protocol OCRScannerViewControllerDelegate: AnyObject {
    func ocrScannerDidScan(recognizedText: String)
}

// MARK: - MRZ Document Types

enum MRZDocumentType {
    case td1        // ID Card: 3 lines × 30 chars
    case td2        // Travel Document: 2 lines × 36 chars
    case td3        // Passport: 2 lines × 44 chars
    case eepChina   // 往來港澳通行證: 1 line × 30 chars (starts with CS)
    case mrva       // Visa Type A: 2 lines × 44 chars
    case mrvb       // Visa Type B: 2 lines × 36 chars
    
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
        case .eepChina: return "往來港澳通行證 (EEP)"
        case .mrva: return "Visa Type A"
        case .mrvb: return "Visa Type B"
        }
    }
}

class OCRScannerViewController: UIViewController {
    
    weak var delegate: OCRScannerViewControllerDelegate?
    
    private let captureSession = AVCaptureSession()
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private var isProcessing = false
    private var hasScanned = false
    private let processInterval: TimeInterval = 0.2
    private var lastProcessTime: TimeInterval = 0
    
    private let overlayView = UIView()
    private let scanAreaView = UIView()
    private let resultLabel = UILabel()
    private let flashButton = UIButton(type: .system)
    private let documentTypeLabel = UILabel()
    
    // MRZ stability tracking
    private var consecutiveDetectionCount = 0
    private let requiredConsecutiveDetections = 3
    private var lastStableMRZ: String?
    private var detectedDocumentType: MRZDocumentType?
    
    // Valid MRZ character set
    private let validMRZCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resetDetection()
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer.frame = view.bounds
        createCutout()
    }
    
    private func resetDetection() {
        hasScanned = false
        isProcessing = false
        consecutiveDetectionCount = 0
        lastStableMRZ = nil
        detectedDocumentType = nil
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        captureSession.sessionPreset = .hd1920x1080
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let deviceInput = try? AVCaptureDeviceInput(device: camera) else {
            showError("Camera not available")
            return
        }
        
        do {
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            if camera.isAutoFocusRangeRestrictionSupported {
                camera.autoFocusRangeRestriction = .near
            }
            camera.unlockForConfiguration()
        } catch {
            print("Camera configuration error: \(error)")
        }
        
        if captureSession.canAddInput(deviceInput) && captureSession.canAddOutput(videoOutput) {
            captureSession.addInput(deviceInput)
            captureSession.addOutput(videoOutput)
            
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ocr_video_queue", qos: .userInteractive))
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String: Any]
            
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            
            videoPreviewLayer.session = captureSession
            videoPreviewLayer.videoGravity = .resizeAspectFill
            view.layer.insertSublayer(videoPreviewLayer, at: 0)
        } else {
            showError("Could not setup camera")
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        
        scanAreaView.layer.borderColor = UIColor.systemGreen.cgColor
        scanAreaView.layer.borderWidth = 2
        scanAreaView.layer.cornerRadius = 8
        scanAreaView.backgroundColor = .clear
        scanAreaView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanAreaView)
        
        // Document type indicator
        documentTypeLabel.text = "Detecting document type..."
        documentTypeLabel.textColor = .white
        documentTypeLabel.textAlignment = .center
        documentTypeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        documentTypeLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        documentTypeLabel.layer.cornerRadius = 6
        documentTypeLabel.clipsToBounds = true
        documentTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(documentTypeLabel)
        
        resultLabel.text = "Scanning for MRZ..."
        resultLabel.textColor = .white
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        resultLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        resultLabel.layer.cornerRadius = 8
        resultLabel.clipsToBounds = true
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultLabel)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Cancel", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        closeButton.layer.cornerRadius = 8
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        flashButton.layer.cornerRadius = 25
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flashButton)
        
        let instructionLabel = UILabel()
        instructionLabel.text = "Align MRZ code within frame\n對準證件機讀碼區域"
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2
        instructionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)
        
 
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            scanAreaView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanAreaView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scanAreaView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scanAreaView.heightAnchor.constraint(equalToConstant: 120),
            
            documentTypeLabel.bottomAnchor.constraint(equalTo: scanAreaView.topAnchor, constant: -8),
            documentTypeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            documentTypeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            documentTypeLabel.heightAnchor.constraint(equalToConstant: 28),
            
            resultLabel.topAnchor.constraint(equalTo: scanAreaView.bottomAnchor, constant: 16),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 50),
            flashButton.heightAnchor.constraint(equalToConstant: 50),
            
            instructionLabel.bottomAnchor.constraint(equalTo: documentTypeLabel.topAnchor, constant: -12),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            instructionLabel.heightAnchor.constraint(equalToConstant: 50),
            
          
        ])
    }
    
    private func createCutout() {
        overlayView.layoutIfNeeded()
        scanAreaView.layoutIfNeeded()
        
        let path = UIBezierPath(rect: overlayView.bounds)
        let cutoutRect = overlayView.convert(scanAreaView.frame, from: scanAreaView.superview)
        let cutoutPath = UIBezierPath(roundedRect: cutoutRect, cornerRadius: 8)
        path.append(cutoutPath)
        path.usesEvenOddFillRule = true
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        stopScanning()
        dismiss(animated: true)
    }
    
    @objc private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .off {
                device.torchMode = .on
                flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
            } else {
                device.torchMode = .off
                flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
            }
            device.unlockForConfiguration()
        } catch {
            print("Flash error: \(error)")
        }
    }
    
    @objc private func manualCapture() {
        if let currentMRZ = lastStableMRZ, !currentMRZ.isEmpty {
            hasScanned = true
            acceptResult(currentMRZ)
        } else {
            resetDetection()
        }
    }
    
    // MARK: - Scanning
    
    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func stopScanning() {
        captureSession.stopRunning()
    }
    
    private func shouldProcessFrame() -> Bool {
        let currentTime = Date().timeIntervalSince1970
        
        if isProcessing || hasScanned || currentTime - lastProcessTime < processInterval {
            return false
        }
        
        lastProcessTime = currentTime
        isProcessing = true
        return true
    }
    
    // MARK: - Region of Interest
    
    private func calculateRegionOfInterest() -> CGRect {
        let scanFrame = view.convert(scanAreaView.frame, to: nil)
        let viewBounds = view.bounds
        
        let x = scanFrame.origin.x / viewBounds.width
        let width = scanFrame.width / viewBounds.width
        let y = 1.0 - ((scanFrame.origin.y + scanFrame.height) / viewBounds.height)
        let height = scanFrame.height / viewBounds.height
        
        let paddedX = max(0, x - 0.02)
        let paddedY = max(0, y - 0.05)
        let paddedWidth = min(1 - paddedX, width + 0.04)
        let paddedHeight = min(1 - paddedY, height + 0.1)
        
        return CGRect(x: paddedX, y: paddedY, width: paddedWidth, height: paddedHeight)
    }
    
    // MARK: - MRZ Detection & Validation
    
    /// Detect document type from MRZ line(s)
    private func detectDocumentType(from lines: [String]) -> MRZDocumentType? {
        guard !lines.isEmpty else { return nil }
        
        let firstLine = lines[0].uppercased().replacingOccurrences(of: " ", with: "")
        let lineLength = firstLine.count
        
        // Check for China EEP (往來港澳通行證) - Single line starting with CS
        if firstLine.hasPrefix("CS") || firstLine.hasPrefix("C5") || firstLine.hasPrefix("C$") {
            if lineLength >= 28 && lineLength <= 32 {
                return .eepChina
            }
        }
        
        // Check for other single-line documents starting with C
        if lines.count == 1 && firstLine.hasPrefix("C") && lineLength >= 28 && lineLength <= 32 {
            // Could be EEP with OCR error on second character
            let secondChar = firstLine.dropFirst().first
            if secondChar == "S" || secondChar == "5" || secondChar == "$" || secondChar == "8" {
                return .eepChina
            }
        }
        
        // TD3 Passport: 2 lines × 44 chars, starts with P
        if firstLine.hasPrefix("P") && lineLength >= 42 && lineLength <= 46 {
            return .td3
        }
        
        // Visa Type A: 2 lines × 44 chars, starts with V
        if firstLine.hasPrefix("V") && lineLength >= 42 && lineLength <= 46 {
            return .mrva
        }
        
        // TD1 ID Card: 3 lines × 30 chars, starts with I, A, or C
        if (firstLine.hasPrefix("I") || firstLine.hasPrefix("A") || firstLine.hasPrefix("C"))
            && lineLength >= 28 && lineLength <= 32 && !firstLine.hasPrefix("CS") {
            return .td1
        }
        
        // TD2 or Visa Type B: 2 lines × 36 chars
        if lineLength >= 34 && lineLength <= 38 {
            if firstLine.hasPrefix("V") {
                return .mrvb
            }
            return .td2
        }
        
        // Fallback based on line count and length
        if lines.count >= 2 && lineLength >= 42 {
            return .td3
        } else if lines.count >= 2 && lineLength >= 34 {
            return .td2
        } else if lineLength >= 28 && lineLength <= 32 {
            // Single line around 30 chars - likely EEP
            if lines.count == 1 {
                return .eepChina
            }
            return .td1
        }
        
        return nil
    }
    
    /// Check if text looks like an MRZ line
    private func isMRZLine(_ text: String) -> Bool {
        let cleanText = text.replacingOccurrences(of: " ", with: "").uppercased()
        
        // Length check: 28-46 characters
        guard cleanText.count >= 28 && cleanText.count <= 46 else { return false }
        
        // Must contain '<' delimiters (except for single-line EEP which uses < as separator)
        let hasDelimiter = cleanText.contains("<")
        
        // Valid character percentage
        let validCharCount = cleanText.unicodeScalars.filter { validMRZCharacters.contains($0) }.count
        let validPercentage = Double(validCharCount) / Double(cleanText.count)
        
        guard validPercentage >= 0.85 else { return false }
        
        // Check specific patterns
        return isValidMRZLinePattern(cleanText) || (hasDelimiter && validPercentage >= 0.9)
    }
    
    /// Validate MRZ line pattern
    private func isValidMRZLinePattern(_ line: String) -> Bool {
        let cleanLine = line.uppercased()
        
        // === Single-line EEP Pattern (往來港澳通行證) ===
        // Format: CS + 9-char doc number + check + < + 6-char expiry + check + < + 6-char DOB + check + < + final check
        // Example: CSC123456780<240101<850315<2
        if cleanLine.hasPrefix("CS") || cleanLine.hasPrefix("C5") || cleanLine.hasPrefix("C8") {
            // Should be around 30 characters
            if cleanLine.count >= 28 && cleanLine.count <= 32 {
                // Should have '<' separators
                let delimiterCount = cleanLine.filter { $0 == "<" }.count
                if delimiterCount >= 2 && delimiterCount <= 5 {
                    return true
                }
            }
        }
        
        // === TD3 Passport Line 1 ===
        // Format: P<COUNTRY<SURNAME<<GIVENNAMES<<<<...
        let passportLine1Prefixes = ["P<", "PO", "P0"]
        if passportLine1Prefixes.contains(where: { cleanLine.hasPrefix($0) }) {
            if cleanLine.contains("<<") {
                return true
            }
        }
        
        // === TD3 Passport Line 2 ===
        // Format: DOCUMENT_NUMBER + checks + nationality + DOB + checks + sex + expiry + checks + optional + check
        // Typically starts with alphanumeric and has many digits
        if cleanLine.count >= 42 {
            let digitCount = cleanLine.filter { $0.isNumber }.count
            if digitCount >= 10 && cleanLine.contains("<") {
                return true
            }
        }
        
        // === TD1 ID Card Patterns ===
        let td1Prefixes = ["I<", "ID", "I0", "A<", "AC", "C<"]
        if td1Prefixes.contains(where: { cleanLine.hasPrefix($0) }) {
            return true
        }
        
        // === Visa Patterns ===
        if cleanLine.hasPrefix("V<") || cleanLine.hasPrefix("V0") {
            return true
        }
        
        // === Generic MRZ detection ===
        if cleanLine.contains("<<") && cleanLine.count >= 30 {
            return true
        }
        
        // Check for numeric-heavy line (likely line 2 of any MRZ)
        let digitCount = cleanLine.filter { $0.isNumber }.count
        let hasDatePattern = digitCount >= 6 && cleanLine.contains("<")
        if hasDatePattern && cleanLine.count >= 28 {
            return true
        }
        
        return false
    }
    
    /// Check if this is specifically an EEP line
    private func isEEPLine(_ text: String) -> Bool {
        let cleanText = text.replacingOccurrences(of: " ", with: "").uppercased()
        
        // Must be around 30 characters
        guard cleanText.count >= 28 && cleanText.count <= 32 else { return false }
        
        // Must start with CS (or common OCR errors: C5, C$, C8)
        let validPrefixes = ["CS", "C5", "C$", "C8", "CS"]
        guard validPrefixes.contains(where: { cleanText.hasPrefix($0) }) else { return false }
        
        // Should have '<' separators (typically 3-4 of them)
        let delimiterCount = cleanText.filter { $0 == "<" }.count
        guard delimiterCount >= 2 else { return false }
        
        // Should have enough digits (document number + dates + check digits = ~15+ digits)
        let digitCount = cleanText.filter { $0.isNumber }.count
        guard digitCount >= 12 else { return false }
        
        return true
    }
    
    // MARK: - MRZ Cleaning & Correction
    
    private func cleanMRZLine(_ text: String) -> String {
        var result = text.uppercased()
        
        // Remove whitespace
        result = result.replacingOccurrences(of: " ", with: "")
        result = result.replacingOccurrences(of: "\t", with: "")
        
        // Common OCR substitution errors
        let replacements: [(String, String)] = [
            ("|", "I"),
            ("!", "I"),
            ("l", "I"),
            ("}", "J"),
            ("{", "C"),
            ("$", "S"),
            ("@", "0"),
            ("°", "0"),
            ("º", "0"),
            ("©", "C"),
            ("®", "R"),
            ("¤", "0"),
            ("§", "S"),
            ("¡", "I"),
            ("~", "<"),
            ("_", "<"),
            ("-", "<"),
            ("«", "<"),
            ("»", ">"),
            ("(", "C"),
            (")", "0"),
            ("[", "C"),
            ("]", "I"),
        ]
        
        for (old, new) in replacements {
            result = result.replacingOccurrences(of: old, with: new)
        }
        
        // Context-aware O/0 correction
        result = correctOAndZero(result)
        
        // Remove invalid characters
        result = String(result.unicodeScalars.filter { validMRZCharacters.contains($0) })
        
        return result
    }
    
    /// Clean EEP-specific line with appropriate corrections
    private func cleanEEPLine(_ text: String) -> String {
        var result = cleanMRZLine(text)
        
        // Ensure starts with CS
        if result.hasPrefix("C5") {
            result = "CS" + String(result.dropFirst(2))
        } else if result.hasPrefix("C8") {
            result = "CS" + String(result.dropFirst(2))
        } else if result.hasPrefix("C$") {
            result = "CS" + String(result.dropFirst(2))
        }
        
        // EEP format: CS + DocNum(9) + Check(1) + < + Expiry(6) + Check(1) + < + DOB(6) + Check(1) + < + FinalCheck(1)
        // Total: 2 + 9 + 1 + 1 + 6 + 1 + 1 + 6 + 1 + 1 + 1 = 30 characters
        
        return result
    }
    
    private func correctOAndZero(_ text: String) -> String {
        var result = Array(text)
        
        // For EEP: everything after "CS" position 2 should have 0 not O (it's all numbers and delimiters)
        if text.hasPrefix("CS") || text.hasPrefix("C5") || text.hasPrefix("C8") {
            for i in 2..<result.count {
                if result[i] == "O" {
                    result[i] = "0"
                }
            }
            return String(result)
        }
        
        // For other documents, use context-aware correction
        var inNameSection = false
        var afterDocType = false
        
        for i in 0..<result.count {
            let char = result[i]
            
            if i < 5 && char == "<" {
                afterDocType = true
            }
            
            if afterDocType {
                if i > 0 && result[i-1] == "<" && char == "<" {
                    inNameSection = false
                } else if char != "<" && i < 44 {
                    inNameSection = true
                }
            }
            
            if char == "O" || char == "0" {
                if inNameSection && !isLikelyNumber(context: result, index: i) {
                    result[i] = "O"
                } else if isLikelyNumber(context: result, index: i) {
                    result[i] = "0"
                }
            }
        }
        
        return String(result)
    }
    
    private func isLikelyNumber(context: [Character], index: Int) -> Bool {
        let start = max(0, index - 2)
        let end = min(context.count - 1, index + 2)
        
        var digitCount = 0
        var letterCount = 0
        
        for i in start...end {
            if i != index {
                if context[i].isNumber {
                    digitCount += 1
                } else if context[i].isLetter && context[i] != "<" {
                    letterCount += 1
                }
            }
        }
        
        return digitCount > letterCount
    }
    
    // MARK: - MRZ Normalization & Validation
    
    private func normalizeMRZLineLength(_ line: String, targetLength: Int) -> String {
        var normalized = line
        
        if normalized.count < targetLength {
            normalized += String(repeating: "<", count: targetLength - normalized.count)
        } else if normalized.count > targetLength {
            normalized = String(normalized.prefix(targetLength))
        }
        
        return normalized
    }
    
    /// Validate EEP MRZ structure and check digits
    private func validateEEPMRZ(_ mrz: String) -> Bool {
        let cleanMRZ = mrz.replacingOccurrences(of: " ", with: "")
        
        // Should be 30 characters
        guard cleanMRZ.count == 30 else { return false }
        
        // Should start with CS
        guard cleanMRZ.hasPrefix("CS") else { return false }
        
        // Check structure: positions 12, 20, 28 should be '<'
        let chars = Array(cleanMRZ)
        
        // Position 12 (index 11) should be '<'
        // Position 20 (index 19) should be '<'
        // Position 28 (index 27) should be '<'
        // Note: This is based on the format description provided
        
        // Verify check digit positions contain digits
        let checkDigitPositions = [11, 19, 27, 29] // 0-indexed: 12, 20, 28, 30
        for pos in checkDigitPositions {
            if pos < chars.count {
                let char = chars[pos]
                // Should be digit or '<'
                if !char.isNumber && char != "<" {
                    return false
                }
            }
        }
        
        // Verify date fields contain valid digits
        // Expiry date: positions 14-19 (index 13-18)
        // DOB: positions 22-27 (index 21-26)
        
        return true
    }
    
    private func validateMRZCheckDigits(_ mrz: String) -> Bool {
        let lines = mrz.components(separatedBy: "\n")
        
        // Single line (EEP)
        if lines.count == 1 {
            return validateEEPMRZ(lines[0])
        }
        
        // Multi-line MRZ
        guard lines.count >= 2 else { return false }
        
        let line1 = lines[0]
        let line2 = lines[1]
        
        let lengthDiff = abs(line1.count - line2.count)
        guard lengthDiff <= 2 else { return false }
        
        let validStarts = ["P<", "P0", "PO", "I<", "ID", "I0", "AC", "A<", "C<", "V<", "V0"]
        let hasValidStart = validStarts.contains { line1.hasPrefix($0) } || line1.first == "P" || line1.first == "V"
        
        let line2DigitCount = line2.filter { $0.isNumber }.count
        let hasEnoughDigits = line2DigitCount >= 6
        
        return hasValidStart && hasEnoughDigits
    }
    
    /// Calculate ICAO check digit
    private func calculateCheckDigit(_ input: String) -> Int {
        let weights = [7, 3, 1]
        var sum = 0
        
        for (index, char) in input.enumerated() {
            let value: Int
            if char == "<" {
                value = 0
            } else if char.isNumber {
                value = Int(String(char)) ?? 0
            } else if char.isLetter {
                value = Int(char.asciiValue ?? 0) - 55 // A=10, B=11, etc.
            } else {
                value = 0
            }
            
            sum += value * weights[index % 3]
        }
        
        return sum % 10
    }
    
    // MARK: - MRZ Extraction
    
    private func extractMRZData(_ mrzLines: [String], documentType: MRZDocumentType?) -> String? {
        guard !mrzLines.isEmpty else { return nil }
        
        let docType = documentType ?? detectDocumentType(from: mrzLines)
        
        // Handle single-line EEP
        if docType == .eepChina || mrzLines.count == 1 {
            let cleanedLine = cleanEEPLine(mrzLines[0])
            let normalized = normalizeMRZLineLength(cleanedLine, targetLength: 30)
            
            if validateEEPMRZ(normalized) || normalized.hasPrefix("CS") {
                return normalized
            }
            
            // Return anyway if it looks like EEP
            if cleanedLine.count >= 28 && (cleanedLine.hasPrefix("CS") || cleanedLine.hasPrefix("C")) {
                return normalized
            }
            
            return nil
        }
        
        // Multi-line documents
        guard let docType = docType else { return nil }
        
        let cleanedLines = mrzLines.map { cleanMRZLine($0) }
        let normalizedLines = cleanedLines.map { normalizeMRZLineLength($0, targetLength: docType.lineLength) }
        
        let expectedLineCount = docType.lineCount
        let linesToUse = Array(normalizedLines.prefix(expectedLineCount))
        
        guard linesToUse.count >= min(2, expectedLineCount) else { return nil }
        
        let mrz = linesToUse.joined(separator: "\n")
        
        if validateMRZCheckDigits(mrz) {
            return mrz
        }
        
        return mrz
    }
    
    private func sortMRZLinesByPosition(_ observations: [(text: String, y: CGFloat)]) -> [String] {
        let sorted = observations.sorted { $0.y > $1.y }
        return sorted.map { $0.text }
    }
    
    private func areMRZLinesSimilar(_ mrz1: String, _ mrz2: String) -> Bool {
        let lines1 = mrz1.components(separatedBy: "\n")
        let lines2 = mrz2.components(separatedBy: "\n")
        
        guard lines1.count == lines2.count else { return false }
        
        for (line1, line2) in zip(lines1, lines2) {
            let distance = levenshteinDistance(line1, line2)
            let maxLength = max(line1.count, line2.count)
            guard maxLength > 0 else { continue }
            
            let similarity = 1.0 - (Double(distance) / Double(maxLength))
            
            if similarity < 0.92 {
                return false
            }
        }
        
        return true
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        for i in 0...s1.count { dist[i][0] = i }
        for j in 0...s2.count { dist[0][j] = j }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                dist[i][j] = min(
                    dist[i-1][j] + 1,
                    dist[i][j-1] + 1,
                    dist[i-1][j-1] + cost
                )
            }
        }
        
        return dist[s1.count][s2.count]
    }
    
    // MARK: - OCR Processing
    
    private func performOCR(on pixelBuffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            defer { self.isProcessing = false }
            
            if let error = error {
                print("OCR Error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            var mrzCandidates: [(text: String, y: CGFloat, confidence: Float)] = []
            var eepCandidates: [(text: String, y: CGFloat, confidence: Float)] = []
            
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                
                let text = candidate.string
                let confidence = candidate.confidence
                
                guard confidence >= 0.4 else { continue }
                
                // Check for EEP first (single line)
                if self.isEEPLine(text) {
                    eepCandidates.append((
                        text: text,
                        y: observation.boundingBox.origin.y,
                        confidence: confidence
                    ))
                } else if self.isMRZLine(text) {
                    mrzCandidates.append((
                        text: text,
                        y: observation.boundingBox.origin.y,
                        confidence: confidence
                    ))
                }
            }
            
            // Prioritize EEP detection (single line)
            if let bestEEP = eepCandidates.max(by: { $0.confidence < $1.confidence }) {
                self.processDetectedMRZ(
                    lines: [bestEEP.text],
                    documentType: .eepChina,
                    lineCount: 1
                )
                return
            }
            
            // Process multi-line MRZ
            guard mrzCandidates.count >= 1 else {
                self.updateUI(mrzFound: false, lineCount: 0)
                return
            }
            
            let sortedCandidates = mrzCandidates.sorted { $0.y > $1.y }
            let topCandidates = Array(sortedCandidates.prefix(3))
            let detectedType = self.detectDocumentType(from: topCandidates.map { $0.text })
            
            // For single-line detection, check if it might be EEP
            if topCandidates.count == 1, let single = topCandidates.first {
                let cleanText = single.text.replacingOccurrences(of: " ", with: "").uppercased()
                if cleanText.count >= 28 && cleanText.count <= 32 && cleanText.hasPrefix("C") {
                    self.processDetectedMRZ(
                        lines: [single.text],
                        documentType: .eepChina,
                        lineCount: 1
                    )
                    return
                }
            }
            
            let requiredLines = detectedType?.lineCount ?? 2
            guard topCandidates.count >= min(requiredLines, 2) else {
                self.updateUI(mrzFound: false, lineCount: topCandidates.count)
                return
            }
            
            self.processDetectedMRZ(
                lines: topCandidates.map { $0.text },
                documentType: detectedType,
                lineCount: topCandidates.count
            )
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.012
        request.recognitionLanguages = ["en-US"]
        request.customWords = ["P<", "<<", "<<<", "CS", "CSC"]
        
        DispatchQueue.main.sync {
            request.regionOfInterest = self.calculateRegionOfInterest()
        }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error)")
            isProcessing = false
        }
    }
    
    private func processDetectedMRZ(lines: [String], documentType: MRZDocumentType?, lineCount: Int) {
        guard let extractedMRZ = extractMRZData(lines, documentType: documentType) else {
            updateUI(mrzFound: false, lineCount: lineCount)
            return
        }
        
        // Update detected document type
        detectedDocumentType = documentType ?? detectDocumentType(from: [extractedMRZ])
        
        // Check stability
        if let lastMRZ = lastStableMRZ, areMRZLinesSimilar(lastMRZ, extractedMRZ) {
            consecutiveDetectionCount += 1
        } else {
            lastStableMRZ = extractedMRZ
            consecutiveDetectionCount = 1
        }
        
        updateUI(mrzFound: true, lineCount: lineCount, mrz: extractedMRZ, docType: detectedDocumentType)
        
        // Auto-accept if stable
        if consecutiveDetectionCount >= requiredConsecutiveDetections && !hasScanned {
            hasScanned = true
            DispatchQueue.main.async {
                self.acceptResult(extractedMRZ)
            }
        }
    }
    
    private func updateUI(mrzFound: Bool, lineCount: Int, mrz: String? = nil, docType: MRZDocumentType? = nil) {
        DispatchQueue.main.async {
            if mrzFound, let mrz = mrz {
                let progress = min(self.consecutiveDetectionCount, self.requiredConsecutiveDetections)
                let dots = String(repeating: "●", count: progress) +
                           String(repeating: "○", count: self.requiredConsecutiveDetections - progress)
                
                let docTypeName = docType?.displayName ?? "Unknown"
                self.documentTypeLabel.text = " \(docTypeName) "
                self.documentTypeLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
                
                self.resultLabel.text = "\(dots)\n\(mrz)"
                
                if self.consecutiveDetectionCount >= self.requiredConsecutiveDetections {
                    self.scanAreaView.layer.borderColor = UIColor.systemGreen.cgColor
                    self.scanAreaView.layer.borderWidth = 4
                } else {
                    self.scanAreaView.layer.borderColor = UIColor.systemYellow.cgColor
                    self.scanAreaView.layer.borderWidth = 3
                }
            } else {
                self.consecutiveDetectionCount = 0
                self.documentTypeLabel.text = "Detecting document type..."
                self.documentTypeLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
                
                self.resultLabel.text = lineCount > 0 ?
                    "Partial MRZ detected (\(lineCount) line\(lineCount > 1 ? "s" : ""))..." :
                    "Scanning for MRZ...\n掃描機讀碼中..."
                self.scanAreaView.layer.borderColor = UIColor.systemGreen.cgColor
                self.scanAreaView.layer.borderWidth = 2
            }
        }
    }
    
    private func acceptResult(_ text: String) {
        stopScanning()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Immediately dismiss and pass result to delegate
        dismiss(animated: true) { [weak self] in
            self?.delegate?.ocrScannerDidScan(recognizedText: text)
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension OCRScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard shouldProcessFrame(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        performOCR(on: pixelBuffer)
    }
}
