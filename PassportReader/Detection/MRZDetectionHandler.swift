
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
    
    // Vision requests
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleRectangleDetection(request: request, error: error)
        }
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.2
        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        return request
    }()
    
    private var currentSampleBuffer: CMSampleBuffer?
    private var detectedMRZType: MRZDocumentType?
    
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
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([rectangleRequest])
        } catch {
            print("⚠️ Rectangle detection failed: \(error)")
            updateUIForNoDetection()
        }
    }
    
    // MARK: - Rectangle Detection Handler
    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation],
              let observation = observations.first else {
            updateUIForNoDetection()
            return
        }
        
        guard let alignmentDetector = alignmentDetector else { return }
        
        let alignmentResult = alignmentDetector.analyzeAlignment(observation: observation)
        
        DispatchQueue.main.async { [weak self] in
            self?.updateUI(with: alignmentResult)
        }
        
        checkStabilityAndTriggerOCR(alignmentResult: alignmentResult)
        
        lastAlignmentResult = alignmentResult
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
        let textRequest = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error)
        }
        
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = false
        textRequest.recognitionLanguages = ["en-US"]
        textRequest.minimumTextHeight = 0.015
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([textRequest])
        } catch {
            print("⚠️ OCR failed: \(error)")
            resetOCRState()
        }
    }
    
    // MARK: - Text Recognition Handler
    private func handleTextRecognition(request: VNRequest, error: Error?) {

        defer { resetOCRState() }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("⚠️ No text observations")
            return
        }
        
        // Extract text with position info for sorting
        var candidates: [(text: String, y: CGFloat, confidence: Float)] = []
        
        for observation in observations {
            if let topCandidate = observation.topCandidates(1).first {
                let text = topCandidate.string
                let y = observation.boundingBox.midY
                let confidence = topCandidate.confidence
                
                // Pre-filter: check if it could be MRZ or EEP
                if mrzValidator.isMRZLine(text) || mrzValidator.isEEPLine(text) {
                    candidates.append((text: text, y: y, confidence: confidence))
                    print("📝 MRZ candidate: \(text) (y: \(y), conf: \(confidence))")
                }
            }
        }
        
        // Also collect all text for fallback
        var allTextLines: [String] = []
        for observation in observations {
            if let topCandidate = observation.topCandidates(1).first {
                allTextLines.append(topCandidate.string)
            }
        }
        
        print("📝 Found \(candidates.count) MRZ candidates from \(observations.count) observations")
        
        // Try to extract and parse MRZ
        if let extracted = mrzExtractor.extractMRZ(from: candidates, cleaner: mrzCleaner, validator: mrzValidator) {
            detectedMRZType = extracted.documentType
            if let result = mrzParserManager?.parseMRZ(lines: extracted.lines) {
                print(result.description)
                // Capture cropped image before showing results
                let croppedImage = captureGuideBoxImage()
                
                DispatchQueue.main.async { [weak self] in
                    self?.showResults(result,capturedImage: croppedImage)
                }
                return
            }
        }else{
            print("📝 cant Found MRZ candidates from \(observations.count) observations")

        }
        
        // Fallback: try parsing all lines
        let filteredLines = allTextLines.filter { $0.contains("<") || mrzValidator.isMRZLine($0) }
        if let result = mrzParserManager?.parseMRZ(lines: filteredLines) {
            print("MRZ parse result: " + result.description)
            let croppedImage = captureGuideBoxImage()
            DispatchQueue.main.async { [weak self] in
                self?.showResults(result,capturedImage: croppedImage)
            }
            return
        }else{
            print("Fail to parseMRZ")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.showParsingError()
        }
    }
    
    // MARK: - UI Updates
    private func updateUI(with result: AlignmentResult) {
        updateInstructionLabel(instruction: result.instruction)
        
        // Update document type based on detected MRZ type or aspect ratio
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
        
        // Convert guide box to image coordinates (flip Y for Core Image)
        let scaleX = fullWidth / previewBounds.width
        let scaleY = fullHeight / previewBounds.height
        
        let cropRect = CGRect(
            x: guideBox.minX * scaleX,
            y: (previewBounds.height - guideBox.maxY) * scaleY,  // Flip Y
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
        
        // Prepare data dictionary
        var data: [String: String] = [
            Constants.EXTRA_DOC_NUM: result.documentNumber,
            Constants.EXTRA_DOB: result.dateOfBirth,
            Constants.EXTRA_EXPIRY: result.expiryDate,
            Constants.EXTRA_DOC_TYPE: result.documentType
        ]
        

        
        // Call delegate instead of showing results view controller
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("🔥 self is nil")
                return
            }
            print("🔥 calling delegate method")
            self.delegate?.detectionHandler(self, didDetectMRZ: data)
        }
    }
//        let resultsVC = ResultsViewController(result: result)
//        resultsVC.onDismiss = { [weak self] in
//            self?.resetScanner()
//        }
//        
//        if let navigationController = context?.navigationController {
//            navigationController.pushViewController(resultsVC, animated: true)
//        } else {
//            context?.present(resultsVC, animated: true)
//        }
//    }
    
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
        guidanceOverlay?.reset()
        resultLabel?.text = nil
        cameraManager?.resumeSession()
    }
    
    func cleanup() {
        resetOCRState()
        currentSampleBuffer = nil
    }
}
