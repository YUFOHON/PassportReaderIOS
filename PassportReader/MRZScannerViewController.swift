import UIKit
import QKMRZScanner

protocol MRZScannerViewControllerDelegate: AnyObject {
    func mrzScannerDidScan(documentNumber: String, dateOfBirth: String, expiryDate: String)
}

class MRZScannerViewController: UIViewController {
    
    weak var delegate: MRZScannerViewControllerDelegate?
    private let scannerView = QKMRZScannerView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup scanner view
        scannerView.translatesAutoresizingMaskIntoConstraints = false
        scannerView.delegate = self
        view.addSubview(scannerView)
        
        NSLayoutConstraint.activate([
            scannerView.topAnchor.constraint(equalTo: view.topAnchor),
            scannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Cancel", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Position passport's MRZ within frame"
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.widthAnchor.constraint(equalToConstant: 300),
            instructionLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scannerView.startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scannerView.stopScanning()
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

extension MRZScannerViewController: QKMRZScannerViewDelegate {
    func mrzScannerView(_ mrzScannerView: QKMRZScannerView, didFind scanResult: QKMRZScanResult) {
        // Convert dates to string format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        
        let documentNumber = scanResult.documentNumber ?? ""
        let dateOfBirth = dateFormatter.string(from: scanResult.birthdate ?? Date())
        let expiryDate = dateFormatter.string(from: scanResult.expiryDate ?? Date())
        
        print("MRZ Scanned:")
        print("Document Number: \(documentNumber)")
        print("Date of Birth: \(dateOfBirth)")
        print("Expiry Date: \(expiryDate)")
        
        dismiss(animated: true) {
            self.delegate?.mrzScannerDidScan(
                documentNumber: documentNumber,
                dateOfBirth: dateOfBirth,
                expiryDate: expiryDate
            )
        }
    }
}
