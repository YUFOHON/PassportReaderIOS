

import UIKit
import AVFoundation

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer)
}

class CameraManager: NSObject {
    
    // MARK: - Properties
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.passportreader.sessionQueue")
    private let outputQueue = DispatchQueue(label: "com.passportreader.outputQueue", qos: .userInitiated)
    
    private weak var previewView: UIView?
    weak var delegate: CameraManagerDelegate?
    var detectionHandler: MRZDetectionHandler?
    
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionRunning = false
    
    // MARK: - Initialization
    init(previewView: UIView, delegate: CameraManagerDelegate?) {
        self.previewView = previewView
        self.delegate = delegate
        super.init()
    }
    
    // MARK: - Camera Setup
    func startCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    func stopCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionRunning else { return }
            self.captureSession.stopRunning()
            self.isSessionRunning = false
            print("🛑 Camera session stopped")
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("❌ Failed to create video input")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Configure video device for optimal scanning
        configureVideoDevice(videoDevice)
        
        // Add video output
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Lock orientation to portrait
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        captureSession.commitConfiguration()
        
        // Setup preview layer on main thread
        DispatchQueue.main.async { [weak self] in
            self?.setupPreviewLayer()
        }
        
        // Start session
        captureSession.startRunning()
        isSessionRunning = true
        print("✅ Camera session started")
    }
    
    private func configureVideoDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // Enable auto focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Enable auto exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Enable auto white balance
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Enable low light boost if available
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            device.unlockForConfiguration()
        } catch {
            print("⚠️ Failed to configure video device: \(error)")
        }
    }
    
    private func setupPreviewLayer() {
        guard let previewView = previewView else { return }
        
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = previewView.bounds
        
        // Lock preview orientation
        if let connection = layer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        previewView.layer.insertSublayer(layer, at: 0)
        self.previewLayer = layer
        
        print("✅ Preview layer configured")
    }
    
    // MARK: - Capture Still Image
    func captureCurrentFrame() -> CVPixelBuffer? {
        // The current frame will be captured via the sample buffer delegate
        return nil
    }
    
    // MARK: - Control Methods
    func pauseSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionRunning else { return }
            self.captureSession.stopRunning()
            self.isSessionRunning = false
            print("⏸️ Camera session paused")
        }
    }
    
    func resumeSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isSessionRunning else { return }
            self.captureSession.startRunning()
            self.isSessionRunning = true
            print("▶️ Camera session resumed")
        }
    }
    
    func cleanup() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            self?.isSessionRunning = false
            print("🧹 Camera manager cleaned up")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraManager(self, didOutput: sampleBuffer)
    }
}
