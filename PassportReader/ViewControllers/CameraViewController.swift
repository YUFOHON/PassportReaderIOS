//
//  CameraViewController.swift
//  PassportReader
//

import Foundation
import UIKit
import AVFoundation
import Vision
import CoreImage

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didScanMRZ data: [String: String])
}

class CameraViewController: UIViewController {
    
    private let TAG = "CameraViewController"
    
    weak var delegate: CameraViewControllerDelegate?

    
    // UI Components
    private var guidanceOverlay: MRZGuidanceOverlay!
    private var instructionLabel: UILabel!
    private var previewView: UIView!
    private var documentTypeLabel: UILabel!
    private var resultLabel: UILabel!
    
    // Managers
    private var cameraManager: CameraManager!
    private var detectionHandler: MRZDetectionHandler!
    private var alignmentDetector: DocumentAlignmentDetector!
    private var mrzParserManager: MrzParserManager!
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initializeViews()
        initializeManagers()
        
        detectionHandler.delegate = self

        
        requestCameraPermission()
        
        // Update cached values after layout
        DispatchQueue.main.async { [weak self] in
            self?.alignmentDetector.updateCachedValues()
            print("📐 Initial cache update triggered")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
        alignmentDetector.updateCachedValues()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    // MARK: - UI Initialization
    private func initializeViews() {
        view.backgroundColor = .black
        
        // Preview View
        previewView = UIView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        
        // Guidance Overlay
        guidanceOverlay = MRZGuidanceOverlay()
        guidanceOverlay.translatesAutoresizingMaskIntoConstraints = false
        guidanceOverlay.backgroundColor = .clear
        view.addSubview(guidanceOverlay)
        
        // Instruction Label
        instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.textAlignment = .center
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.layer.cornerRadius = 10
        instructionLabel.clipsToBounds = true
        instructionLabel.numberOfLines = 2
        instructionLabel.text = "Place document inside the frame"
        view.addSubview(instructionLabel)
        
        // Document Type Label
        documentTypeLabel = UILabel()
        documentTypeLabel.translatesAutoresizingMaskIntoConstraints = false
        documentTypeLabel.textAlignment = .center
        documentTypeLabel.textColor = .white
        documentTypeLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        documentTypeLabel.backgroundColor = UIColor.darkGray
        documentTypeLabel.layer.cornerRadius = 6
        documentTypeLabel.clipsToBounds = true
        documentTypeLabel.isHidden = true
        view.addSubview(documentTypeLabel)
        
        // Result Label
        resultLabel = UILabel()
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.textAlignment = .center
        resultLabel.textColor = .white
        resultLabel.numberOfLines = 0
        resultLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.addSubview(resultLabel)
        
        // Title Label
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Scan Document"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        setupConstraints(titleLabel: titleLabel)
    }
    
    private func setupConstraints(titleLabel: UILabel) {
        NSLayoutConstraint.activate([
            // Preview View
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Guidance Overlay
            guidanceOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            guidanceOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guidanceOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            guidanceOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Instruction Label
            instructionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            instructionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // Document Type Label
            documentTypeLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 12),
            documentTypeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            documentTypeLabel.heightAnchor.constraint(equalToConstant: 28),
            documentTypeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Result Label
            resultLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Manager Initialization
    private func initializeManagers() {
        mrzParserManager = MrzParserManager()
        
        // Step 1: Create alignment detector
        alignmentDetector = DocumentAlignmentDetector(
            guidanceOverlay: guidanceOverlay,
            previewView: previewView
        )
        
        // Step 2: Create camera manager
        cameraManager = CameraManager(
            previewView: previewView,
            delegate: self
        )
        
        // Step 3: Create detection handler
        detectionHandler = MRZDetectionHandler(
            context: self,
            guidanceOverlay: guidanceOverlay,
            instructionLabel: instructionLabel,
            documentTypeLabel: documentTypeLabel,
            resultLabel: resultLabel,
            mrzParserManager: mrzParserManager,
            alignmentDetector: alignmentDetector,
            cameraManager: cameraManager,
            delegate: self
        )
        
        // Step 4: Set detection handler
        cameraManager.detectionHandler = detectionHandler
        
        // Store preview layer
        previewLayer = cameraManager.previewLayer
    }
    
    // MARK: - Camera Permission
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraManager.startCamera()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.cameraManager.startCamera()
                } else {
                    self?.showPermissionDenied()
                }
            }
            
        case .denied, .restricted:
            showPermissionDenied()
            
        @unknown default:
            break
        }
    }
    
    private func showPermissionDenied() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Camera Permission Required",
                message: "Please enable camera access in Settings to scan documents.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self?.present(alert, animated: true)
        }
    }
    
    // MARK: - Cleanup
    deinit {
        cameraManager?.cleanup()
        detectionHandler?.cleanup()
    }
}

// MARK: - CameraManagerDelegate
extension CameraViewController: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer) {
        detectionHandler.analyzeImage(sampleBuffer)
    }
}

extension CameraViewController: MRZDetectionHandlerDelegate {
    func detectionHandler(_ handler: MRZDetectionHandler, didDetectMRZ data: [String: String]) {
        print("🔥 CameraViewController received MRZ data: \(data)")

        // Stop camera
        cameraManager.stopCamera()
        
        // Dismiss this view controller and pass data back
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            print("🔥 dismiss completed, calling ViewController delegate")

            self.delegate?.cameraViewController(self, didScanMRZ: data)
        }
    }
}
