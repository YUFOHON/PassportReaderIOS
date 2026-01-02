import UIKit
import CoreNFC

class ViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "📘 Passport NFC Reader"
        label.font = .boldSystemFont(ofSize: 24)
        label.textColor = .systemBlue
        label.textAlignment = .center
        return label
    }()
    
    private let instructionsLabel: UILabel = {
        let label = UILabel()
        label.text = """
        📍 NFC Reading Tips:
        • Remove passport from cover
        • Place on flat surface
        • Position iPhone on passport center
        • Keep VERY STILL for 10-15 seconds
        • Don't move until complete
        """
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private let docNumberField: UITextField = {
        let field = UITextField()
        field.placeholder = "Document Number (e.g., H23837428)"
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        return field
    }()
    
    private let birthDateField: UITextField = {
        let field = UITextField()
        field.placeholder = "Date of Birth (YYMMDD)"
        field.borderStyle = .roundedRect
        field.keyboardType = .numberPad
        return field
    }()
    
    private let expiryDateField: UITextField = {
        let field = UITextField()
        field.placeholder = "Expiry Date (YYMMDD)"
        field.borderStyle = .roundedRect
        field.keyboardType = .numberPad
        return field
    }()
    
    private let verifyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🔍 Verify MRZ Data", for: .normal)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        return button
    }()
    
    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📷 Scan MRZ", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        return button
    }()
    
    private let readNFCButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📱 Read NFC", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        return button
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Scan MRZ or enter passport details manually"
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progress = 0
        progress.isHidden = true
        return progress
    }()
    
    private let faceImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemGray5
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let resultTextView: UITextView = {
        let textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.cornerRadius = 8
        return textView
    }()
    
    // MARK: - Properties
    private let passportReader = PassportReader()
    private var retryCount = 0
    private let maxRetries = 3
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        checkNFCAvailability()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add all subviews
        [titleLabel, instructionsLabel, docNumberField, birthDateField, expiryDateField,
         verifyButton, scanButton, readNFCButton, statusLabel, progressView, faceImageView, resultTextView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Instructions
            instructionsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            instructionsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            instructionsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Document Number
            docNumberField.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 20),
            docNumberField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            docNumberField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            docNumberField.heightAnchor.constraint(equalToConstant: 44),
            
            // Birth Date
            birthDateField.topAnchor.constraint(equalTo: docNumberField.bottomAnchor, constant: 12),
            birthDateField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            birthDateField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            birthDateField.heightAnchor.constraint(equalToConstant: 44),
            
            // Expiry Date
            expiryDateField.topAnchor.constraint(equalTo: birthDateField.bottomAnchor, constant: 12),
            expiryDateField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            expiryDateField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            expiryDateField.heightAnchor.constraint(equalToConstant: 44),
            
            // Verify Button
            verifyButton.topAnchor.constraint(equalTo: expiryDateField.bottomAnchor, constant: 12),
            verifyButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            verifyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            verifyButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Scan Button
            scanButton.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 20),
            scanButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scanButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scanButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Read NFC Button
            readNFCButton.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 12),
            readNFCButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            readNFCButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            readNFCButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: readNFCButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Face Image
            faceImageView.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 20),
            faceImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            faceImageView.widthAnchor.constraint(equalToConstant: 200),
            faceImageView.heightAnchor.constraint(equalToConstant: 250),
            
            // Result TextView
            resultTextView.topAnchor.constraint(equalTo: faceImageView.bottomAnchor, constant: 20),
            resultTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultTextView.heightAnchor.constraint(equalToConstant: 400),
            resultTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        verifyButton.addTarget(self, action: #selector(verifyMRZTapped), for: .touchUpInside)
        scanButton.addTarget(self, action: #selector(scanMRZTapped), for: .touchUpInside)
        readNFCButton.addTarget(self, action: #selector(readNFCTapped), for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func checkNFCAvailability() {
        if !NFCNDEFReaderSession.readingAvailable {
            statusLabel.text = "⚠️ NFC not available on this device"
            readNFCButton.isEnabled = false
            readNFCButton.backgroundColor = .systemGray
        }
    }
    
    // MARK: - MRZ Key Generation
    
    /// Calculates the check digit for MRZ fields according to ICAO Doc 9303
    private func calculateCheckDigit(_ input: String) -> String {
        let weights = [7, 3, 1]
        var sum = 0
        
        for (index, char) in input.enumerated() {
            let value: Int
            if char.isNumber {
                value = Int(String(char)) ?? 0
            } else if char == "<" {
                value = 0
            } else {
                // A=10, B=11, ..., Z=35
                let asciiValue = char.uppercased().unicodeScalars.first?.value ?? 0
                value = Int(asciiValue) - 55
            }
            sum += value * weights[index % 3]
        }
        
        return String(sum % 10)
    }
    
    /// Pads the document number to 9 characters with '<' as per ICAO standard
    private func padDocumentNumber(_ docNum: String) -> String {
        var padded = docNum.uppercased()
        while padded.count < 9 {
            padded += "<"
        }
        return String(padded.prefix(9))
    }
    
    /// Creates the MRZ key in the format expected by NFCPassportReader
    private func createMRZKey(documentNumber: String, dateOfBirth: String, expiryDate: String) -> String {
        let paddedDocNum = padDocumentNumber(documentNumber)
        let docCheckDigit = calculateCheckDigit(paddedDocNum)
        let dobCheckDigit = calculateCheckDigit(dateOfBirth)
        let expiryCheckDigit = calculateCheckDigit(expiryDate)
        
        let mrzKey = paddedDocNum + docCheckDigit + dateOfBirth + dobCheckDigit + expiryDate + expiryCheckDigit
        
        return mrzKey
    }
    
    // MARK: - Actions
    
    @objc private func verifyMRZTapped() {
        dismissKeyboard()
        
        guard let docNum = docNumberField.text?.trimmingCharacters(in: .whitespaces).uppercased(), !docNum.isEmpty,
              let dob = birthDateField.text?.trimmingCharacters(in: .whitespaces), !dob.isEmpty,
              let expiry = expiryDateField.text?.trimmingCharacters(in: .whitespaces), !expiry.isEmpty else {
            showAlert(title: "Missing Data", message: "Please enter all passport details")
            return
        }
        
        // Validate formats
        guard dob.count == 6, expiry.count == 6 else {
            showAlert(title: "Invalid Format", message: "Dates must be in YYMMDD format (6 digits)")
            return
        }
        
        guard dob.allSatisfy({ $0.isNumber }), expiry.allSatisfy({ $0.isNumber }) else {
            showAlert(title: "Invalid Format", message: "Dates must contain only numbers")
            return
        }
        
        // Create and display MRZ key
        let paddedDocNum = padDocumentNumber(docNum)
        let docCheckDigit = calculateCheckDigit(paddedDocNum)
        let dobCheckDigit = calculateCheckDigit(dob)
        let expiryCheckDigit = calculateCheckDigit(expiry)
        
        let mrzKey = createMRZKey(documentNumber: docNum, dateOfBirth: dob, expiryDate: expiry)
        
        var verificationText = """
        ═══════════════════════════════
        🔍 MRZ VERIFICATION
        ═══════════════════════════════
        
        Document Number: \(paddedDocNum)
        Check Digit: \(docCheckDigit)
        
        Date of Birth: \(dob)
        Check Digit: \(dobCheckDigit)
        
        Expiry Date: \(expiry)
        Check Digit: \(expiryCheckDigit)
        
        ───────────────────────────────
        Complete MRZ Key:
        \(mrzKey)
        ───────────────────────────────
        
        ✅ MRZ data verified!
        Ready to read NFC chip.
        
        """
        
        resultTextView.text = verificationText
        statusLabel.text = "✅ MRZ Verified! Tap 'Read NFC' when ready."
        statusLabel.textColor = .systemGreen
    }
    
    @objc private func scanMRZTapped() {
        let scannerVC = MRZScannerViewController()
        scannerVC.delegate = self
        scannerVC.modalPresentationStyle = .fullScreen
        present(scannerVC, animated: true)
    }
    
    @objc private func readNFCTapped() {
        dismissKeyboard()
        
        guard let docNum = docNumberField.text?.trimmingCharacters(in: .whitespaces).uppercased(), !docNum.isEmpty,
              let dob = birthDateField.text?.trimmingCharacters(in: .whitespaces), !dob.isEmpty,
              let expiry = expiryDateField.text?.trimmingCharacters(in: .whitespaces), !expiry.isEmpty else {
            showAlert(title: "Missing Data", message: "Please scan MRZ or enter all passport details")
            return
        }
        
        // Validate date formats
        guard dob.count == 6, expiry.count == 6 else {
            showAlert(title: "Invalid Format", message: "Dates must be in YYMMDD format")
            return
        }
        
        guard dob.allSatisfy({ $0.isNumber }), expiry.allSatisfy({ $0.isNumber }) else {
            showAlert(title: "Invalid Format", message: "Dates must contain only numbers")
            return
        }
        
        retryCount = 0
        attemptNFCRead(docNum: docNum, dob: dob, expiry: expiry)
    }
    
    private func attemptNFCRead(docNum: String, dob: String, expiry: String) {
        statusLabel.text = """
        📱 HOLD PASSPORT STEADY
        Position iPhone on passport center
        DO NOT MOVE for 15 seconds
        
        Attempt \(retryCount + 1) of \(maxRetries)
        """
        statusLabel.textColor = .systemOrange
        resultTextView.text = ""
        faceImageView.image = nil
        progressView.isHidden = false
        progressView.progress = 0
        
        // Create properly formatted MRZ key
        let mrzKey = createMRZKey(documentNumber: docNum, dateOfBirth: dob, expiryDate: expiry)
        
        print("\n🔑 ═══════════════════════════════")
        print("Attempt \(retryCount + 1): Reading passport")
        print("MRZ Key: \(mrzKey)")
        print("═══════════════════════════════\n")
        
        // Simulate progress
        animateProgress()
        
        passportReader.readPassport(mrzKey: mrzKey) { [weak self] result in
            DispatchQueue.main.async {
                self?.progressView.isHidden = true
                self?.handleNFCResult(result, docNum: docNum, dob: dob, expiry: expiry)
            }
        }
    }
    
    private func animateProgress() {
        progressView.setProgress(0.3, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.progressView.setProgress(0.6, animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.progressView.setProgress(0.9, animated: true)
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Result Handling
    private func handleNFCResult(_ result: Result<PassportReader.PassportData, Error>, docNum: String, dob: String, expiry: String) {
        switch result {
        case .success(let data):
            statusLabel.text = "✅ Passport Read Complete!"
            statusLabel.textColor = .systemGreen
            displayPassportData(data)
            retryCount = 0
            
        case .failure(let error):
            let errorMessage = error.localizedDescription
            
            // Check if it's a communication error
            if errorMessage.contains("Tag response error") ||
               errorMessage.contains("no response") ||
               errorMessage.contains("Tag Error") {
                
                retryCount += 1
                
                if retryCount < maxRetries {
                    statusLabel.text = """
                    ⚠️ Lost connection to passport
                    
                    Please try again:
                    • Place passport flat on table
                    • Remove from any covers
                    • Position iPhone directly on center
                    • Keep VERY STILL
                    
                    Retry \(retryCount + 1) of \(maxRetries)
                    """
                    statusLabel.textColor = .systemOrange
                    
                    // Show retry alert
                    let alert = UIAlertController(
                        title: "Connection Lost",
                        message: """
                        The passport chip didn't respond. This usually means:
                        
                        • Passport moved during reading
                        • Poor NFC coupling
                        • Metal interference nearby
                        
                        Try again? (\(retryCount)/\(maxRetries) attempts)
                        """,
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Retry Now", style: .default) { [weak self] _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.attemptNFCRead(docNum: docNum, dob: dob, expiry: expiry)
                        }
                    })
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                        self?.retryCount = 0
                        self?.statusLabel.text = "❌ Reading cancelled"
                        self?.statusLabel.textColor = .systemRed
                    })
                    
                    present(alert, animated: true)
                } else {
                    statusLabel.text = """
                    ❌ Failed after \(maxRetries) attempts
                    
                    Troubleshooting:
                    • Verify MRZ data is correct
                    • Try different position on passport
                    • Ensure no metal objects nearby
                    • Check passport isn't damaged
                    """
                    statusLabel.textColor = .systemRed
                    retryCount = 0
                }
                
            } else if errorMessage.contains("InvalidMRZKey") || errorMessage.contains("BAC Failed") {
                statusLabel.text = """
                ❌ Authentication Failed
                
                MRZ data is incorrect!
                Please:
                • Double-check all entered data
                • Use 'Scan MRZ' for accuracy
                • Verify check digits
                """
                statusLabel.textColor = .systemRed
                retryCount = 0
                
                showAlert(
                    title: "Invalid MRZ Data",
                    message: """
                    The passport rejected the authentication.
                    
                    This means the Document Number, Date of Birth, or Expiry Date is wrong.
                    
                    Please scan the MRZ again or carefully re-enter the data.
                    """
                )
            } else {
                statusLabel.text = "❌ Error: \(errorMessage)"
                statusLabel.textColor = .systemRed
                retryCount = 0
                showAlert(title: "Read Failed", message: errorMessage)
            }
        }
    }
    
    private func displayPassportData(_ data: PassportReader.PassportData) {
        var result = """
        ═══════════════════════════════
        📘 PASSPORT INFORMATION
        ═══════════════════════════════
        
        """
        
        // SOD Section
        result += """
        ───────────────────────────────
        🔐 SECURITY OBJECT (SOD)
        ───────────────────────────────
        """
        
        if let sodData = data.rawSODData {
            result += "\nStatus: \(data.hasValidSignature ? "Valid ✓" : "Invalid")\n"
            result += "Signer: \(data.signingCountry ?? "Unknown")\n"
            result += "Size: \(sodData.count) bytes\n"
            
            if !data.dataGroupHashes.isEmpty {
                result += "\nData Group Hashes:\n"
                let sortedHashes = data.dataGroupHashes.sorted { $0.key.rawValue < $1.key.rawValue }
                for (dgId, hashBytes) in sortedHashes {
                    let hashHex = hashBytes.map { String(format: "%02X", $0) }.joined()
                    let truncatedHash = hashHex.count > 20 ? String(hashHex.prefix(20)) + "..." : hashHex
                    result += "  • \(dgId.getName()): \(truncatedHash)\n"
                }
            }
        } else {
            result += "\n⚠️ SOD not read\n"
        }
        
        result += "\n"
        
        // DG1 - Basic Information
        result += """
        ───────────────────────────────
        📄 BASIC INFORMATION (DG1)
        ───────────────────────────────
        """
        
        result += "\nDocument Type: \(data.documentCode ?? "N/A")\n"
        result += "Document Number: \(data.documentNumber ?? "N/A")\n"
        result += "Name: \(data.firstName ?? "") \(data.lastName ?? "")\n"
        result += "Nationality: \(data.nationality ?? "N/A")\n"
        result += "Issuing Country: \(data.issuingState ?? "N/A")\n"
        result += "Gender: \(data.gender ?? "N/A")\n"
        result += "Date of Birth: \(formatDate(data.dateOfBirth))\n"
        result += "Date of Expiry: \(formatDate(data.dateOfExpiry))\n"
        
        if let optData = data.optionalData1, !optData.isEmpty {
            result += "Optional Data: \(optData)\n"
        }
        
        result += "\n"
        
        // DG2 - Face Image
        result += """
        📸 FACIAL IMAGE (DG2)
        ───────────────────────────────
        """
        
        if !data.faceImages.isEmpty {
            result += "\nImages: \(data.faceImages.count) photo(s)\n"
            for (index, mimeType) in data.faceImageMimeTypes.enumerated() {
                result += "  Format \(index + 1): \(mimeType)\n"
            }
            faceImageView.image = data.faceImages[0]
        } else {
            result += "\nNo face image available\n"
        }
        
        result += "\n"
        
        // DG11 - Additional Details
        if data.fullName != nil || !data.placeOfBirth.isEmpty || !data.address.isEmpty {
            result += """
            ℹ️ ADDITIONAL DETAILS (DG11)
            ───────────────────────────────
            """
            
            if let fullName = data.fullName {
                result += "\nFull Name: \(fullName)\n"
            }
            if let personalNumber = data.personalNumber {
                result += "Personal Number: \(personalNumber)\n"
            }
            if !data.placeOfBirth.isEmpty {
                result += "Place of Birth: \(data.placeOfBirth.joined(separator: ", "))\n"
            }
            if !data.address.isEmpty {
                result += "Address: \(data.address.joined(separator: ", "))\n"
            }
            if let telephone = data.telephone {
                result += "Telephone: \(telephone)\n"
            }
            if let profession = data.profession {
                result += "Profession: \(profession)\n"
            }
            result += "\n"
        }
        
        // DG12 - Document Details
        if data.issuingAuthority != nil || data.dateOfIssue != nil {
            result += """
            📋 DOCUMENT DETAILS (DG12)
            ───────────────────────────────
            """
            
            if let issuingAuthority = data.issuingAuthority {
                result += "\nIssuing Authority: \(issuingAuthority)\n"
            }
            if let dateOfIssue = data.dateOfIssue {
                result += "Date of Issue: \(dateOfIssue)\n"
            }
            if let endorsements = data.endorsementsAndObservations {
                result += "Endorsements: \(endorsements)\n"
            }
            result += "\n"
        }
        
        // Security Information
        result += """
        🔐 SECURITY INFORMATION
        ───────────────────────────────
        """
        
        result += "\nAuthentication: \(data.authenticationMethod.rawValue)\n"
        result += "Chip Auth: \(data.hasChipAuthentication ? "Yes ✓" : "No")\n"
        result += "Active Auth: \(data.hasActiveAuthentication ? "Yes ✓" : "No")\n"
        result += "Digital Signature: \(data.hasValidSignature ? "Valid ✓" : "Not verified")\n"
        
        result += "\n"
        
        result += """
        ═══════════════════════════════
        ✅ Read completed successfully
        ═══════════════════════════════
        """
        
        resultTextView.text = result
    }
    
    private func formatDate(_ yymmdd: String?) -> String {
        guard let yymmdd = yymmdd, yymmdd.count == 6 else {
            return yymmdd ?? "N/A"
        }
        
        let yearStr = String(yymmdd.prefix(2))
        let monthStr = String(yymmdd.dropFirst(2).prefix(2))
        let dayStr = String(yymmdd.suffix(2))
        
        guard let yy = Int(yearStr) else { return yymmdd }
        let fullYear = (yy > 50) ? (1900 + yy) : (2000 + yy)
        
        return "\(dayStr)/\(monthStr)/\(fullYear)"
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - MRZ Scanner Delegate
extension ViewController: MRZScannerViewControllerDelegate {
    func mrzScannerDidScan(documentNumber: String, dateOfBirth: String, expiryDate: String) {
        print("✓ MRZ Data received:")
        print("  Document Number: '\(documentNumber)'")
        print("  Date of Birth: '\(dateOfBirth)'")
        print("  Expiry Date: '\(expiryDate)'")
        
        DispatchQueue.main.async { [weak self] in
            self?.docNumberField.text = documentNumber
            self?.birthDateField.text = dateOfBirth
            self?.expiryDateField.text = expiryDate
            
            self?.statusLabel.text = "✅ MRZ Scanned! Use 'Verify MRZ Data' to check, then 'Read NFC'."
            self?.statusLabel.textColor = .systemGreen
        }
    }
}
