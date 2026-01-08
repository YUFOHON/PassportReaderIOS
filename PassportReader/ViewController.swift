import UIKit
import CoreNFC

class ViewController: UIViewController, OCRScannerViewControllerDelegate {
    
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
    
    private let documentTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "Document Type: Not detected"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGray
        label.textAlignment = .center
        return label
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
    private let eepReader = EepDocumentReader()
    private var retryCount = 0
    private let maxRetries = 3
    
    // Document type tracking
    private enum DetectedDocumentType {
        case passport
        case eep
        case unknown
    }
    private var currentDocumentType: DetectedDocumentType = .unknown
    
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
         documentTypeLabel, verifyButton, scanButton, readNFCButton, statusLabel, progressView,
         faceImageView, resultTextView].forEach {
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
            
            // Document Type Label
            documentTypeLabel.topAnchor.constraint(equalTo: expiryDateField.bottomAnchor, constant: 12),
            documentTypeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            documentTypeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Verify Button
            verifyButton.topAnchor.constraint(equalTo: documentTypeLabel.bottomAnchor, constant: 12),
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
                let asciiValue = char.uppercased().unicodeScalars.first?.value ?? 0
                value = Int(asciiValue) - 55
            }
            sum += value * weights[index % 3]
        }
        
        return String(sum % 10)
    }
    
    private func padDocumentNumber(_ docNum: String) -> String {
        var padded = docNum.uppercased()
        while padded.count < 9 {
            padded += "<"
        }
        return String(padded.prefix(9))
    }
    
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
        
        guard dob.count == 6, expiry.count == 6 else {
            showAlert(title: "Invalid Format", message: "Dates must be in YYMMDD format (6 digits)")
            return
        }
        
        guard dob.allSatisfy({ $0.isNumber }), expiry.allSatisfy({ $0.isNumber }) else {
            showAlert(title: "Invalid Format", message: "Dates must contain only numbers")
            return
        }
        
        let paddedDocNum = padDocumentNumber(docNum)
        let docCheckDigit = calculateCheckDigit(paddedDocNum)
        let dobCheckDigit = calculateCheckDigit(dob)
        let expiryCheckDigit = calculateCheckDigit(expiry)
        
        let mrzKey = createMRZKey(documentNumber: docNum, dateOfBirth: dob, expiryDate: expiry)
        
        let documentTypeString: String
        switch currentDocumentType {
        case .passport:
            documentTypeString = "TD3 Passport"
        case .eep:
            documentTypeString = "往來港澳通行證 (EEP)"
        case .unknown:
            documentTypeString = "Unknown (will auto-detect)"
        }
        
        let verificationText = """
        ═══════════════════════════════
        🔍 MRZ VERIFICATION
        ═══════════════════════════════
        
        Document Type: \(documentTypeString)
        
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
        let ocrScanner = OCRScannerViewController()
        ocrScanner.delegate = self
        ocrScanner.modalPresentationStyle = .fullScreen
        present(ocrScanner, animated: true)
    }
    
    @objc private func readNFCTapped() {
        dismissKeyboard()
        
        guard let docNum = docNumberField.text?.trimmingCharacters(in: .whitespaces).uppercased(), !docNum.isEmpty,
              let dob = birthDateField.text?.trimmingCharacters(in: .whitespaces), !dob.isEmpty,
              let expiry = expiryDateField.text?.trimmingCharacters(in: .whitespaces), !expiry.isEmpty else {
            showAlert(title: "Missing Data", message: "Please scan MRZ or enter all passport details")
            return
        }
        
        guard dob.count == 6, expiry.count == 6 else {
            showAlert(title: "Invalid Format", message: "Dates must be in YYMMDD format")
            return
        }
        
        guard dob.allSatisfy({ $0.isNumber }), expiry.allSatisfy({ $0.isNumber }) else {
            showAlert(title: "Invalid Format", message: "Dates must contain only numbers")
            return
        }
        
        retryCount = 0
        
        // Route to appropriate reader based on document type
        switch currentDocumentType {
        case .eep:
            attemptEEPRead(docNum: docNum, dob: dob, expiry: expiry)
        case .passport:
            attemptPassportRead(docNum: docNum, dob: dob, expiry: expiry)
        case .unknown:
            // Default to passport reader, could also show a picker
            showDocumentTypePicker(docNum: docNum, dob: dob, expiry: expiry)
        }
    }
    
    private func showDocumentTypePicker(docNum: String, dob: String, expiry: String) {
        let alert = UIAlertController(
            title: "Select Document Type",
            message: "Document type was not detected. Please select your document type:",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "🛂 Passport (TD3)", style: .default) { [weak self] _ in
            self?.currentDocumentType = .passport
            self?.updateDocumentTypeUI()
            self?.attemptPassportRead(docNum: docNum, dob: dob, expiry: expiry)
        })
        
        alert.addAction(UIAlertAction(title: "🇭🇰 往來港澳通行證 (EEP)", style: .default) { [weak self] _ in
            self?.currentDocumentType = .eep
            self?.updateDocumentTypeUI()
            self?.attemptEEPRead(docNum: docNum, dob: dob, expiry: expiry)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = readNFCButton
            popover.sourceRect = readNFCButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Passport NFC Read
    
    private func attemptPassportRead(docNum: String, dob: String, expiry: String) {
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
        
        let mrzKey = createMRZKey(documentNumber: docNum, dateOfBirth: dob, expiryDate: expiry)
        
        print("\n🔑 ═══════════════════════════════")
        print("Passport Read - Attempt \(retryCount + 1)")
        print("MRZ Key: \(mrzKey)")
        print("═══════════════════════════════\n")
        
        animateProgress()
        
        passportReader.readPassport(mrzKey: mrzKey) { [weak self] result in
            DispatchQueue.main.async {
                self?.progressView.isHidden = true
                self?.handlePassportResult(result, docNum: docNum, dob: dob, expiry: expiry)
            }
        }
    }
    
    // MARK: - EEP NFC Read
    
    private func attemptEEPRead(docNum: String, dob: String, expiry: String) {
        statusLabel.text = """
        📱 請將手機靠近通行證
        Hold iPhone near the permit
        保持不動 15 秒
        
        Attempt \(retryCount + 1) of \(maxRetries)
        """
        statusLabel.textColor = .systemOrange
        resultTextView.text = ""
        faceImageView.image = nil
        progressView.isHidden = false
        progressView.progress = 0
        
        let mrzKey = createMRZKey(documentNumber: docNum, dateOfBirth: dob, expiryDate: expiry)
        
        print("\n🔑 ═══════════════════════════════")
        print("EEP Read - Attempt \(retryCount + 1)")
        print("MRZ Key: \(mrzKey)")
        print("═══════════════════════════════\n")
        
        animateProgress()
        let authData = EepDocumentReader.AuthData(
            documentNumber: docNum,
            dateOfBirth: dob,
            dateOfExpiry: expiry
        )
        eepReader.readDocument(authData: authData) { [weak self] result in
            DispatchQueue.main.async {
                self?.progressView.isHidden = true
                self?.handleEEPResult(result, docNum: docNum, dob: dob, expiry: expiry)
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
    
    // MARK: - OCR Scanner Delegate
    
    func ocrScannerDidScan(recognizedText: String) {
        print("📷 OCR Scanned: \(recognizedText)")
        
        // Parse the MRZ using your parsers
        let lines = recognizedText.split(separator: "\n").map(String.init)
        let parsers: [MrzParser] = [EepMrzParser(), Td3PassportParser()]
        
        var parsedData: [String: String]?
        var usedParser: MrzParser?
        
        for line in lines {
            for parser in parsers {
                if parser.canParse(line) {
                    if let data = parser.parse(line) {
                        parsedData = data
                        usedParser = parser
                        break
                    }
                }
            }
            if parsedData != nil { break }
        }
        
        // Also try parsing the full text for multi-line MRZ
        if parsedData == nil {
            let fullText = recognizedText.replacingOccurrences(of: "\n", with: "")
            for parser in parsers {
                if parser.canParse(fullText) {
                    if let data = parser.parse(fullText) {
                        parsedData = data
                        usedParser = parser
                        break
                    }
                }
            }
        }
        
        guard let data = parsedData else {
            showAlert(title: "Parse Error", message: "Could not parse MRZ data from scan")
            return
        }
        
        // Determine document type and populate fields
        let docType = data["DOC_TYPE"] ?? ""
        
        if docType == "EEP" || usedParser is EepMrzParser {
            currentDocumentType = .eep
            print("✅ Detected: EEP (往來港澳通行證)")
        } else if docType == "TD3_PASSPORT" || usedParser is Td3PassportParser {
            currentDocumentType = .passport
            print("✅ Detected: TD3 Passport")
        } else {
            currentDocumentType = .unknown
            print("⚠️ Unknown document type: \(docType)")
        }
        
        // Populate text fields
        if let docNum = data["DOC_NUM"] {
            docNumberField.text = docNum
        }
        
        if let dob = data["DOB"] {
            birthDateField.text = dob
        }
        
        if let expiry = data["EXPIRY"] {
            expiryDateField.text = expiry
        }
        
        // Update UI
        updateDocumentTypeUI()
        
        // Show parsed data in result view
        var resultText = """
        ═══════════════════════════════
        📷 MRZ SCAN RESULT
        ═══════════════════════════════
        
        """
        
        for (key, value) in data.sorted(by: { $0.key < $1.key }) {
            resultText += "\(key): \(value)\n"
        }
        
        resultText += """
        
        ───────────────────────────────
        ✅ Fields populated automatically
        Tap 'Verify MRZ Data' to check
        ───────────────────────────────
        """
        
        resultTextView.text = resultText
        statusLabel.text = "✅ MRZ scanned! Verify and read NFC."
        statusLabel.textColor = .systemGreen
    }
    
    private func updateDocumentTypeUI() {
        switch currentDocumentType {
        case .passport:
            documentTypeLabel.text = "📘 Document Type: TD3 Passport"
            documentTypeLabel.textColor = .systemBlue
            titleLabel.text = "📘 Passport NFC Reader"
            readNFCButton.setTitle("📱 Read Passport NFC", for: .normal)
        case .eep:
            documentTypeLabel.text = "🇭🇰 Document Type: 往來港澳通行證 (EEP)"
            documentTypeLabel.textColor = .systemPurple
            titleLabel.text = "🇭🇰 EEP NFC Reader"
            readNFCButton.setTitle("📱 Read EEP NFC", for: .normal)
        case .unknown:
            documentTypeLabel.text = "❓ Document Type: Not detected"
            documentTypeLabel.textColor = .systemGray
            titleLabel.text = "📘 Document NFC Reader"
            readNFCButton.setTitle("📱 Read NFC", for: .normal)
        }
    }
    
    // MARK: - Result Handling
    
    private func handlePassportResult(_ result: Result<PassportReader.PassportData, Error>, docNum: String, dob: String, expiry: String) {
        switch result {
        case .success(let data):
            statusLabel.text = "✅ Passport Read Complete!"
            statusLabel.textColor = .systemGreen
            displayPassportData(data)
            retryCount = 0
            
        case .failure(let error):
            handleNFCError(error, docNum: docNum, dob: dob, expiry: expiry, isEEP: false)
        }
    }
    
    private func handleEEPResult(_ result: Result<EepDocumentReader.DocumentData, Error>, docNum: String, dob: String, expiry: String) {
        switch result {
        case .success(let data):
            statusLabel.text = "✅ 通行證讀取完成! EEP Read Complete!"
            statusLabel.textColor = .systemGreen
            displayEEPData(data)
            retryCount = 0
            
        case .failure(let error):
            handleNFCError(error, docNum: docNum, dob: dob, expiry: expiry, isEEP: true)
        }
    }
    
    private func handleNFCError(_ error: Error, docNum: String, dob: String, expiry: String, isEEP: Bool) {
        let errorMessage = error.localizedDescription
        
        if errorMessage.contains("Tag response error") ||
           errorMessage.contains("no response") ||
           errorMessage.contains("Tag Error") {
            
            retryCount += 1
            
            if retryCount < maxRetries {
                let documentName = isEEP ? "通行證/permit" : "passport"
                statusLabel.text = """
                ⚠️ Lost connection to \(documentName)
                
                Please try again:
                • Place \(documentName) flat on table
                • Remove from any covers
                • Position iPhone directly on center
                • Keep VERY STILL
                
                Retry \(retryCount + 1) of \(maxRetries)
                """
                statusLabel.textColor = .systemOrange
                
                let alert = UIAlertController(
                    title: "Connection Lost",
                    message: """
                    The chip didn't respond. This usually means:
                    
                    • Document moved during reading
                    • Poor NFC coupling
                    • Metal interference nearby
                    
                    Try again? (\(retryCount)/\(maxRetries) attempts)
                    """,
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Retry Now", style: .default) { [weak self] _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if isEEP {
                            self?.attemptEEPRead(docNum: docNum, dob: dob, expiry: expiry)
                        } else {
                            self?.attemptPassportRead(docNum: docNum, dob: dob, expiry: expiry)
                        }
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
                • Try different position on document
                • Ensure no metal objects nearby
                • Check document isn't damaged
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
                The document rejected the authentication.
                
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
    
    // MARK: - Display Data
    private func displayEEPData(_ data: EepDocumentReader.DocumentData) {
        var result = """
        ═══════════════════════════════
        🇭🇰 往來港澳通行證 INFORMATION
        ═══════════════════════════════
        
        """
        
        // Security Object (SOD) - EXPANDED SECTION
        result += """
        ───────────────────────────────
        🔐 SECURITY OBJECT (SOD)
        ───────────────────────────────
        """
        
        result += "\nSOD Present: \(data.sodPresent ? "Yes ✓" : "No ✗")\n"
        
        // Note: The refactored version removed these fields, so comment them out or remove
        // if let digestAlgo = data.sodDigestAlgorithm {
        //     result += "Digest Algorithm: \(digestAlgo)\n"
        // }
        // if let sigAlgo = data.sodSignatureAlgorithm {
        //     result += "Signature Algorithm: \(sigAlgo)\n"
        // }
        // if let ldsVersion = data.sodLdsVersion {
        //     result += "LDS Version: \(ldsVersion)\n"
        // }
        
        // Display all Data Group hashes
        if !data.dataGroupHashes.isEmpty {
            result += "\n📊 DATA GROUP HASHES:\n"
            result += "───────────────────────────────\n"
            
            let sortedHashes = data.dataGroupHashes.sorted { $0.key < $1.key }
            
            for (dgNumber, hashHex) in sortedHashes {
                let dgName = getDataGroupName(dgNumber)
                result += "\n[\(dgName)]\n"
                
                // Format hash in blocks of 64 characters (32 bytes)
                let formattedHash = formatHashForDisplay(hashHex)
                result += formattedHash
                result += "\n"
            }
        } else {
            result += "\n⚠️ No data group hashes available\n"
        }
        
        result += "\n"
        
        // Document Info
        result += """
        ───────────────────────────────
        📄 DOCUMENT INFORMATION
        ───────────────────────────────
        """
        result += "\n"
//        result += "Document Type: \(data.documentType.rawValue)\n"
//        result += "Document Code: \(data.documentCode ?? "N/A")\n"
        result += "Card Number: \(data.cardNumber ?? "N/A")\n"
        result += "Issuing Country: \(data.issuingCountry ?? "N/A")\n"
        
        result += "\n"
        
        // Personal Info
        result += """
        👤 PERSONAL INFORMATION
        ───────────────────────────────
        """
        
        if let chineseName = data.chineseName {
            result += "\n中文姓名: \(chineseName)\n"
        }
        if let pinyinName = data.pinyinName {
            result += "Pinyin Name: \(pinyinName)\n"
        }
        result += "Nationality: \(data.nationality ?? "N/A")\n"
        result += "Gender: \(data.gender ?? "N/A")\n"
        result += "Date of Birth: \(data.dateOfBirth ?? "N/A")\n"
        result += "Date of Expiry: \(data.dateOfExpiry ?? "N/A")\n"
        result += "Place of Birth: \(data.placeOfBirth ?? "N/A")\n"

        result += "\n"
        
        // Face Image
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
        
        // Optional data from DG11
        if data.personalNumber != nil || data.telephone != nil ||
           data.profession != nil || data.address != nil {
            result += """
            ℹ️ ADDITIONAL DETAILS (DG11)
            ───────────────────────────────
            """
            
            if let personalNumber = data.personalNumber {
                result += "\nPersonal Number: \(personalNumber)\n"
            }
            if let telephone = data.telephone {
                result += "Telephone: \(telephone)\n"
            }
            if let profession = data.profession {
                result += "Profession: \(profession)\n"
            }
            if let address = data.address {
                result += "Address: \(address)\n"
            }
            result += "\n"
        }
        
        // Optional data from DG12
        if data.issuingAuthority != nil || data.dateOfIssue != nil ||
           data.endorsementsAndObservations != nil {
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
        
        // Security Info
        result += """
        🔐 SECURITY INFORMATION
        ───────────────────────────────
        """
        
        result += "\nAuthentication: \(data.authenticationMethod ?? "N/A")\n"
        result += "Chip Auth: \(data.hasChipAuthentication ? "Yes ✓" : "No")\n"
        result += "Active Auth: \(data.hasActiveAuthentication ? "Yes ✓" : "No")\n"
        result += "MRZ Checksum: \(data.checksumValid ? "Valid ✓" : "Invalid ✗")\n"
        result += "SOD Signature: \(data.hasValidSignature ? "Valid ✓" : "Invalid ✗")\n"
        
        if !data.availableDataGroups.isEmpty {
            result += "\nAvailable Data Groups:\n"
            let dgList = data.availableDataGroups.sorted().map { "DG\($0)" }.joined(separator: ", ")
            result += "  \(dgList)\n"
        }
        
        if let activeAuthKey = data.activeAuthPublicKey {
            result += "\nActive Auth Public Key:\n"
            result += "  \(String(activeAuthKey.prefix(64)))...\n"
        }
        
        result += "\n"
        
        result += """
        ═══════════════════════════════
        ✅ Read completed successfully
        ═══════════════════════════════
        """
        
        resultTextView.text = result
    }

    private func displayPassportData(_ data: PassportReader.PassportData) {
        var result = """
        ═══════════════════════════════
        📘 PASSPORT INFORMATION
        ═══════════════════════════════
        
        """
        
        // SOD Section - EXPANDED
        result += """
        ───────────────────────────────
        🔐 SECURITY OBJECT (SOD)
        ───────────────────────────────
        """
        
        if let sodData = data.rawSODData {
            result += "Size: \(sodData.count) bytes\n"
            
//            if let digestAlgo = data.sodDigestAlgorithm {
//                result += "Digest Algorithm: \(digestAlgo)\n"
//            }
//            if let sigAlgo = data.sodSignatureAlgorithm {
//                result += "Signature Algorithm: \(sigAlgo)\n"
//            }
            
            // Display all Data Group hashes
            if !data.dataGroupHashes.isEmpty {
                result += "\n📊 DATA GROUP HASHES:\n"
                result += "───────────────────────────────\n"
                
                let sortedHashes = data.dataGroupHashes.sorted { $0.key.rawValue < $1.key.rawValue }
                
                for (dgId, hashBytes) in sortedHashes {
                    let dgName = dgId.getName()
                    let hashHex = hashBytes.map { String(format: "%02X", $0) }.joined()
                    
                    result += "\n[\(dgName)]\n"
                    
                    // Format hash in blocks
                    let formattedHash = formatHashForDisplay(hashHex)
                    result += formattedHash
                    
                    // Add hash length info
                    result += "  Length: \(hashBytes.count) bytes"
                    result += "\n"
                }
            } else {
                result += "\n⚠️ No data group hashes available\n"
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
        result += "Date of Birth: \(String(describing: data.dateOfBirth)))\n"
        result += "Date of Expiry: \(String(describing: data.dateOfExpiry))\n"
//        result += "Date of Birth: \(formatDate(data.dateOfBirth))\n"
//        result += "Date of Expiry: \(formatDate(data.dateOfExpiry))\n"
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

        result += "\n"
        
        result += """
        ═══════════════════════════════
        ✅ Read completed successfully
        ═══════════════════════════════
        """
        
        resultTextView.text = result
    }

    // MARK: - Helper Methods for Hash Display

    /// Format hash string for readable display (with line breaks every 64 characters)
    private func formatHashForDisplay(_ hashHex: String) -> String {
        let charsPerLine = 64
        var formatted = ""
        var currentIndex = hashHex.startIndex
        
        while currentIndex < hashHex.endIndex {
            let endIndex = hashHex.index(currentIndex, offsetBy: charsPerLine, limitedBy: hashHex.endIndex) ?? hashHex.endIndex
            let line = String(hashHex[currentIndex..<endIndex])
            formatted += "  \(line)\n"
            currentIndex = endIndex
        }
        
        return formatted
    }

    /// Get human-readable name for Data Group number
    private func getDataGroupName(_ dgNumber: Int) -> String {
        switch dgNumber {
        case 0: return "DG0 (COM)"
        case 1: return "DG1 (MRZ)"
        case 2: return "DG2 (Face)"
        case 3: return "DG3 (Fingerprints)"
        case 4: return "DG4 (Iris)"
        case 5: return "DG5 (Portrait)"
        case 6: return "DG6 (Reserved)"
        case 7: return "DG7 (Signature)"
        case 8: return "DG8 (Data Features)"
        case 9: return "DG9 (Structure Features)"
        case 10: return "DG10 (Substance Features)"
        case 11: return "DG11 (Additional Personal)"
        case 12: return "DG12 (Additional Document)"
        case 13: return "DG13 (Optional Details)"
        case 14: return "DG14 (Security Options)"
        case 15: return "DG15 (Active Auth Public Key)"
        case 16: return "DG16 (Persons to Notify)"
        case 99: return "SOD (Security Object)"
        default: return "DG\(dgNumber) (Unknown)"
        }
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


