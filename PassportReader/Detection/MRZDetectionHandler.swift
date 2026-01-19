import UIKit
import Vision
import CoreImage
import os

protocol MRZDetectionHandlerDelegate: AnyObject {
    func detectionHandler(_ handler: MRZDetectionHandler, didDetectMRZ data: [String: String])
}

class MRZDetectionHandler {
    
    weak var delegate: MRZDetectionHandlerDelegate?

    // MARK: - Properties
    private weak var context: UIViewController?
    private weak var guidanceOverlay: MRZGuidanceOverlay?
    private weak var instructionLabel: UILabel?
    private weak var documentTypeLabel: UILabel?
    private weak var resultLabel: UILabel?
    private var mrzParserManager: MrzParserManager?
    private var alignmentDetector: DocumentAlignmentDetector?
    private weak var cameraManager: CameraManager?
    
    // Detection state
    private var isProcessingOCR = false
    private var lastProcessTime: Date = Date()
    private let processingInterval: TimeInterval = 0.1
    
    // Stability tracking
    private var stableFrameCount = 0
    private let requiredStableFrames = 3
    private var lastAlignmentResult: AlignmentResult?
    
    // MRZ detection components
    private let mrzValidator = MRZValidator()
    private let mrzCleaner = MRZCleaner()
    private let mrzExtractor = MRZExtractor()
    
    // Document Segmentation Request (iOS 15+)
    private lazy var documentSegmentationRequest: VNDetectDocumentSegmentationRequest = {
        let request = VNDetectDocumentSegmentationRequest { [weak self] request, error in
            self?.handleDocumentSegmentation(request: request, error: error)
        }
        return request
    }()
    
    // Fallback rectangle request for older iOS
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleRectangleDetection(request: request, error: error)
        }
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.2
        request.maximumObservations = 1
        request.minimumConfidence = 0.5
        request.quadratureTolerance = 15
        return request
    }()
    
    private var currentSampleBuffer: CMSampleBuffer?
    private var detectedMRZType: MRZDocumentType?
    
    private var smoothedRect: CGRect?
    private let smoothingFactor: CGFloat = 0.3
    
    // MARK: - Initialization
    init(context: UIViewController,
         guidanceOverlay: MRZGuidanceOverlay,
         instructionLabel: UILabel,
         documentTypeLabel: UILabel,
         resultLabel: UILabel,
         mrzParserManager: MrzParserManager,
         alignmentDetector: DocumentAlignmentDetector,
         cameraManager: CameraManager,
         delegate: MRZDetectionHandlerDelegate?
    ) {
        self.context = context
        self.guidanceOverlay = guidanceOverlay
        self.instructionLabel = instructionLabel
        self.documentTypeLabel = documentTypeLabel
        self.resultLabel = resultLabel
        self.mrzParserManager = mrzParserManager
        self.alignmentDetector = alignmentDetector
        self.cameraManager = cameraManager
        self.delegate = delegate
    }
    
    // MARK: - Image Analysis
    func analyzeImage(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= processingInterval else { return }
        guard !isProcessingOCR else { return }
        
        lastProcessTime = now
        currentSampleBuffer = sampleBuffer
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        do {
            if #available(iOS 17.0, *) {
                try handler.perform([documentSegmentationRequest])
            } else {
                try handler.perform([rectangleRequest])
            }
        } catch {
            print("⚠️ Document detection failed: \(error)")
            updateUIForNoDetection()
        }
    }
    // MARK: - Document Segmentation Handler (iOS 15+)
    @available(iOS 17.0, *)
    private func handleDocumentSegmentation(request: VNRequest, error: Error?) {
        if let error = error {
            print("⚠️ Document segmentation error: \(error)")
            updateUIForNoDetection()
            return
        }
        
        guard let results = request.results as? [VNRectangleObservation],
              let observation = results.first else {
            smoothedRect = nil
            updateUIForNoDetection()
            return
        }
        
        let confidence = observation.confidence
        print("📄 Document detected with confidence: \(confidence)")
        
        guard confidence > 0.5 else {
            updateUIForNoDetection()
            return
        }
        
        processDocumentObservation(boundingBox: observation.boundingBox, confidence: confidence)
    }
    
    // MARK: - Rectangle Detection Handler (Fallback)
    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation],
              let observation = observations.first else {
            smoothedRect = nil
            updateUIForNoDetection()
            return
        }
        
        processDocumentObservation(boundingBox: observation.boundingBox, confidence: observation.confidence)
    }
    
    // MARK: - Common Processing
    private func processDocumentObservation(boundingBox: CGRect, confidence: Float) {
        guard let alignmentDetector = alignmentDetector else { return }
        
        // Convert Vision coordinates to UIKit coordinates
        let previewBounds = alignmentDetector.cachedPreviewBounds
        guard previewBounds.width > 0, previewBounds.height > 0 else { return }
        
        let documentRect = convertVisionToUIKit(boundingBox, in: previewBounds)
        
        // Apply smoothing
        let smoothedDocument = smoothRect(documentRect)
        
        // Analyze alignment
        let alignmentResult = analyzeDocumentAlignment(
            documentRect: smoothedDocument,
            confidence: CGFloat(confidence)
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.updateUI(with: alignmentResult)
        }
        
        checkStabilityAndTriggerOCR(alignmentResult: alignmentResult)
        lastAlignmentResult = alignmentResult
    }
    
    private func convertVisionToUIKit(_ visionRect: CGRect, in bounds: CGRect) -> CGRect {
        // Vision coordinates are rotated 90° relative to UIKit when camera is portrait
        // Swap x/y and width/height
        let x = (1 - visionRect.maxY) * bounds.width
        let y = visionRect.minX * bounds.height
        let width = visionRect.height * bounds.width
        let height = visionRect.width * bounds.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func analyzeDocumentAlignment(documentRect: CGRect, confidence: CGFloat) -> AlignmentResult {
        guard let alignmentDetector = alignmentDetector else {
            return .notDetected
        }
        
        let guideBox = alignmentDetector.guideBoxFrame
        guard guideBox.width > 0, guideBox.height > 0 else {
            return .notDetected
        }
        
        // Calculate metrics
        let sizeRatio = calculateSizeRatio(documentRect: documentRect, guideBox: guideBox)
        let centerOffset = calculateCenterOffset(documentRect: documentRect, guideBox: guideBox)
        let overlapRatio = calculateOverlapRatio(documentRect: documentRect, guideBox: guideBox)
        
        // Detect document type
        let aspectRatio = documentRect.width / documentRect.height
        let documentType = DocumentType.detect(from: aspectRatio)
        
        // Determine instruction
        let instruction = determineInstruction(
            sizeRatio: sizeRatio,
            centerOffset: centerOffset,
            overlapRatio: overlapRatio
        )
        
        let isAligned = instruction == .holdSteady
        
        print("📐 Size: \(String(format: "%.2f", sizeRatio)), Offset: (\(String(format: "%.2f", centerOffset.x)), \(String(format: "%.2f", centerOffset.y))), Overlap: \(String(format: "%.2f", overlapRatio)), Aligned: \(isAligned)")
        
        return AlignmentResult(
            instruction: instruction,
            isAligned: isAligned,
            confidence: confidence,
            detectedRect: documentRect,
            documentType: documentType
        )
    }
    
    // MARK: - Alignment Calculations
    private func calculateSizeRatio(documentRect: CGRect, guideBox: CGRect) -> CGFloat {
        let widthRatio = documentRect.width / guideBox.width
        let heightRatio = documentRect.height / guideBox.height
        return (widthRatio + heightRatio) / 2
    }
    
    private func calculateCenterOffset(documentRect: CGRect, guideBox: CGRect) -> CGPoint {
        let docCenter = CGPoint(x: documentRect.midX, y: documentRect.midY)
        let guideCenter = CGPoint(x: guideBox.midX, y: guideBox.midY)
        
        return CGPoint(
            x: (docCenter.x - guideCenter.x) / guideBox.width,
            y: (docCenter.y - guideCenter.y) / guideBox.height
        )
    }
    
    private func calculateOverlapRatio(documentRect: CGRect, guideBox: CGRect) -> CGFloat {
        let intersection = documentRect.intersection(guideBox)
        guard !intersection.isNull else { return 0 }
        
        let intersectionArea = intersection.width * intersection.height
        let guideBoxArea = guideBox.width * guideBox.height
        
        return intersectionArea / guideBoxArea
    }
    
    private func determineInstruction(sizeRatio: CGFloat, centerOffset: CGPoint, overlapRatio: CGFloat) -> AlignmentInstruction {
        let sizeThresholdMin: CGFloat = 0.70
        let sizeThresholdMax: CGFloat = 1.20
        let centerOffsetThreshold: CGFloat = 0.10
        let overlapThreshold: CGFloat = 0.80
        
        if sizeRatio < sizeThresholdMin {
            return .moveCloser
        }
        
        if sizeRatio > sizeThresholdMax {
            return .moveBackward
        }
        
        if centerOffset.x < -centerOffsetThreshold {
            return .moveRight
        }
        
        if centerOffset.x > centerOffsetThreshold {
            return .moveLeft
        }
        
        if centerOffset.y < -centerOffsetThreshold {
            return .moveDown
        }
        
        if centerOffset.y > centerOffsetThreshold {
            return .moveUp
        }
        
        if overlapRatio < overlapThreshold {
            return .placeDocument
        }
        
        return .holdSteady
    }
    
    private func smoothRect(_ newRect: CGRect) -> CGRect {
        guard let previous = smoothedRect else {
            smoothedRect = newRect
            return newRect
        }
        
        let smoothed = CGRect(
            x: previous.minX + (newRect.minX - previous.minX) * smoothingFactor,
            y: previous.minY + (newRect.minY - previous.minY) * smoothingFactor,
            width: previous.width + (newRect.width - previous.width) * smoothingFactor,
            height: previous.height + (newRect.height - previous.height) * smoothingFactor
        )
        smoothedRect = smoothed
        return smoothed
    }
    
    // MARK: - Stability Check
    private func checkStabilityAndTriggerOCR(alignmentResult: AlignmentResult) {
        if alignmentResult.isAligned {
            stableFrameCount += 1
            if stableFrameCount >= requiredStableFrames {
                triggerOCR()
            }
        } else {
            stableFrameCount = 0
        }
    }
    
    // MARK: - OCR Trigger
    private func triggerOCR() {
        guard !isProcessingOCR else { return }
        guard let sampleBuffer = currentSampleBuffer,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        isProcessingOCR = true
        stableFrameCount = 0
        
        DispatchQueue.main.async { [weak self] in
            self?.updateInstructionLabel(instruction: .processing)
            self?.guidanceOverlay?.showSuccessAnimation()
        }
        
        performOCR(on: pixelBuffer)
    }
    
    // MARK: - OCR Processing
    private func performOCR(on pixelBuffer: CVPixelBuffer) {
        guard let croppedImage = cropToGuideBox(pixelBuffer: pixelBuffer) else {
            resetOCRState()
            return
        }
        
        let textRequest = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error)
        }
        
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = false
        textRequest.recognitionLanguages = ["en-US"]
        textRequest.minimumTextHeight = 0.015
        
        let handler = VNImageRequestHandler(ciImage: croppedImage, orientation: .up, options: [:])
        
        do {
            try handler.perform([textRequest])
        } catch {
            print("⚠️ OCR failed: \(error)")
            resetOCRState()
        }
    }
    
    private func cropToGuideBox(pixelBuffer: CVPixelBuffer) -> CIImage? {
        guard let alignmentDetector = alignmentDetector else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let fullWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let fullHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        let guideBox = alignmentDetector.guideBoxFrame
        let previewBounds = alignmentDetector.cachedPreviewBounds
        
        guard previewBounds.width > 0, previewBounds.height > 0 else { return nil }
        
        let scaleX = fullWidth / previewBounds.width
        let scaleY = fullHeight / previewBounds.height
        
        let cropRect = CGRect(
            x: guideBox.minX * scaleX,
            y: (previewBounds.height - guideBox.maxY) * scaleY,
            width: guideBox.width * scaleX,
            height: guideBox.height * scaleY
        )
        
        return ciImage.cropped(to: cropRect)
    }
    
    // MARK: - Text Recognition Handler
    private func handleTextRecognition(request: VNRequest, error: Error?) {
        defer { resetOCRState() }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("⚠️ No text observations")
            return
        }
        
        var candidates: [(text: String, y: CGFloat, confidence: Float)] = []
        
        for observation in observations {
            if let topCandidate = observation.topCandidates(1).first {
                let text = topCandidate.string
                let y = observation.boundingBox.midY
                let confidence = topCandidate.confidence
                
                if mrzValidator.isMRZLine(text) || mrzValidator.isEEPLine(text) {
                    candidates.append((text: text, y: y, confidence: confidence))
                    print("📝 MRZ candidate: \(text) (y: \(y), conf: \(confidence))")
                }
            }
        }
        
        var allTextLines: [String] = []
        for observation in observations {
            if let topCandidate = observation.topCandidates(1).first {
                allTextLines.append(topCandidate.string)
            }
        }
        
        print("📝 Found \(candidates.count) MRZ candidates from \(observations.count) observations")
        
        if let extracted = mrzExtractor.extractMRZ(from: candidates, cleaner: mrzCleaner, validator: mrzValidator) {
            detectedMRZType = extracted.documentType
            if let result = mrzParserManager?.parseMRZ(lines: extracted.lines) {
                print(result.description)
                let croppedImage = captureGuideBoxImage()
                
                DispatchQueue.main.async { [weak self] in
                    self?.showResults(result, capturedImage: croppedImage)
                }
                return
            }
        } else {
            print("📝 Can't find MRZ candidates from \(observations.count) observations")
        }
        
        let filteredLines = allTextLines.filter { $0.contains("<") || mrzValidator.isMRZLine($0) }
        if let result = mrzParserManager?.parseMRZ(lines: filteredLines) {
            print("MRZ parse result: " + result.description)
            let croppedImage = captureGuideBoxImage()
            DispatchQueue.main.async { [weak self] in
                self?.showResults(result, capturedImage: croppedImage)
            }
            return
        } else {
            print("Fail to parseMRZ")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.showParsingError()
        }
    }
    
    // MARK: - UI Updates
    private func updateUI(with result: AlignmentResult) {
        updateInstructionLabel(instruction: result.instruction)
        
        if let mrzType = detectedMRZType {
            updateDocumentTypeLabelWithMRZType(mrzType)
        } else {
            updateDocumentTypeLabel(type: result.documentType)
        }
        
        guidanceOverlay?.updateBorderColor(result.instruction.borderColor)
        guidanceOverlay?.updateDetectedRect(result.detectedRect)
    }
    
    private func updateUIForNoDetection() {
        stableFrameCount = 0
        detectedMRZType = nil
        smoothedRect = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.updateInstructionLabel(instruction: .placeDocument)
            self?.updateDocumentTypeLabel(type: nil)
            self?.guidanceOverlay?.updateBorderColor(.white)
            self?.guidanceOverlay?.updateDetectedRect(nil)
        }
    }
    
    private func updateInstructionLabel(instruction: AlignmentInstruction) {
        instructionLabel?.text = instruction.rawValue
        instructionLabel?.textColor = instruction.color
    }
    
    private func updateDocumentTypeLabel(type: DocumentType?) {
        if let type = type {
            documentTypeLabel?.text = "  \(type.rawValue)  "
            documentTypeLabel?.backgroundColor = type.displayColor
            documentTypeLabel?.isHidden = false
        } else {
            documentTypeLabel?.isHidden = true
        }
    }
    
    private func updateDocumentTypeLabelWithMRZType(_ type: MRZDocumentType) {
        let displayName: String
        let color: UIColor
        
        switch type {
        case .td3:
            displayName = "Passport"
            color = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0)
        case .td1:
            displayName = "ID Card"
            color = UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0)
        case .eepChina:
            displayName = "EEP (往來港澳通行證)"
            color = UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0)
        case .td2:
            displayName = "Travel Document"
            color = UIColor(red: 0.5, green: 0.7, blue: 0.3, alpha: 1.0)
        case .mrva, .mrvb:
            displayName = "Visa"
            color = UIColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1.0)
        }
        
        documentTypeLabel?.text = "  \(displayName)  "
        documentTypeLabel?.backgroundColor = color
        documentTypeLabel?.isHidden = false
    }
    
    private func captureGuideBoxImage() -> UIImage? {
        guard let sampleBuffer = currentSampleBuffer,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let alignmentDetector = alignmentDetector else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let fullWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let fullHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        let guideBox = alignmentDetector.guideBoxFrame
        let previewBounds = alignmentDetector.cachedPreviewBounds
        
        guard previewBounds.width > 0, previewBounds.height > 0 else { return nil }
        
        let scaleX = fullWidth / previewBounds.width
        let scaleY = fullHeight / previewBounds.height
        
        let cropRect = CGRect(
            x: guideBox.minX * scaleX,
            y: (previewBounds.height - guideBox.maxY) * scaleY,
            width: guideBox.width * scaleX,
            height: guideBox.height * scaleY
        )
        
        let croppedCI = ciImage.cropped(to: cropRect)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(croppedCI, from: croppedCI.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Results Display
    private func showResults(_ result: MRZResult, capturedImage: UIImage?) {
        print("🔥 showResults called")
        print("🔥 delegate is: \(String(describing: delegate))")
        cameraManager?.pauseSession()
        
        if let image = capturedImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        
        print("\n✅ ═══════════════════════════════")
        print("FINAL MRZ SCAN SUCCESS")
        print("═══════════════════════════════")
        print("Document Number: \(result.documentNumber)")
        print("Date of Birth: \(result.dateOfBirth)")
        print("Date of Expiry: \(result.expiryDate)")
        print("Document Type: \(result.documentType)")
        print("═══════════════════════════════\n")
        
        let data: [String: String] = [
            Constants.EXTRA_DOC_NUM: result.documentNumber,
            Constants.EXTRA_DOB: result.dateOfBirth,
            Constants.EXTRA_EXPIRY: result.expiryDate,
            Constants.EXTRA_DOC_TYPE: result.documentType
        ]
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("🔥 self is nil")
                return
            }
            print("🔥 calling delegate method")
            self.delegate?.detectionHandler(self, didDetectMRZ: data)
        }
    }
    
    private func showParsingError() {
        resultLabel?.text = "Could not parse document. Please try again."
        resultLabel?.textColor = .systemRed
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.resultLabel?.text = nil
        }
    }
    
    // MARK: - State Management
    private func resetOCRState() {
        isProcessingOCR = false
        stableFrameCount = 0
    }
    
    private func resetScanner() {
        resetOCRState()
        detectedMRZType = nil
        smoothedRect = nil
        guidanceOverlay?.reset()
        resultLabel?.text = nil
        cameraManager?.resumeSession()
    }
    
    func cleanup() {
        resetOCRState()
        currentSampleBuffer = nil
    }
}
