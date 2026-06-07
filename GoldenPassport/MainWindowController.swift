import Cocoa
import CoreImage

final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate {
    private enum FormMode {
        case viewing
        case adding
        case editing
    }

    private var entries: [AuthEntry] = []
    private var selectedTag: String?
    private var formMode: FormMode = .viewing
    private var refreshTimer: Timer?

    private let tableView = NSTableView()
    private let nameField = NSTextField()
    private let urlTextView = NSTextView()
    private let codeLabel = NSTextField(labelWithString: "")
    private let expiryLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let httpPortField = NSTextField()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: L("menu.launch_at_login"), target: nil, action: nil)
    private let httpAutoStartButton = NSButton(checkboxWithTitle: L("menu.http.auto_start"), target: nil, action: nil)

    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let deleteButton = NSButton(title: "-", target: nil, action: nil)
    private let scanQRButton = NSButton(title: L("main.scan_qr"), target: nil, action: nil)
    private let editButton = NSButton(title: L("main.edit"), target: nil, action: nil)
    private let saveButton = NSButton(title: L("main.save"), target: nil, action: nil)
    private let cancelButton = NSButton(title: L("main.cancel"), target: nil, action: nil)
    private let copyButton = NSButton(title: L("main.copy_code"), target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GoldenPassport"
        window.minSize = NSSize(width: 860, height: 540)
        super.init(window: window)
        setupUI()
        reloadData(selecting: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
        startRefreshTimer()
        reloadData(selecting: selectedTag)
    }

    override func close() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        super.close()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("AuthCell")
        let textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        textField.identifier = identifier
        textField.lineBreakMode = .byTruncatingTail
        textField.stringValue = entries[row].tag
        return textField
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 && row < entries.count else {
            selectedTag = nil
            showEmptyState()
            return
        }

        selectedTag = entries[row].tag
        formMode = .viewing
        populateDetails(for: entries[row])
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard row >= 0 && row < entries.count else {
            return nil
        }
        return entries[row].tag as NSString
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        guard let draggedTag = info.draggingPasteboard.string(forType: .string),
              let sourceIndex = entries.firstIndex(where: { $0.tag == draggedTag }) else {
            return false
        }

        DataManager.shared.moveAuthEntry(from: sourceIndex, to: row)
        selectedTag = draggedTag
        reloadData(selecting: draggedTag)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "VerifyKeyAdded"), object: nil)
        return true
    }

    func textDidEndEditing(_ notification: Notification) {
        updateNameFromURLIfNeeded()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        let otpItem = NSTabViewItem(identifier: "otp")
        otpItem.label = "OTP"
        otpItem.view = makeOTPView()
        tabView.addTabViewItem(otpItem)

        let settingsItem = NSTabViewItem(identifier: "settings")
        settingsItem.label = L("main.settings")
        settingsItem.view = makeSettingsView()
        tabView.addTabViewItem(settingsItem)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func makeOTPView() -> NSView {
        let container = NSView()
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(split)

        let listPane = makeListPane()
        let detailPane = makeDetailPane()
        split.addArrangedSubview(listPane)
        split.addArrangedSubview(detailPane)

        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            split.topAnchor.constraint(equalTo: container.topAnchor),
            split.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            listPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
            detailPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 520)
        ])

        return container
    }

    private func makeListPane() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let title = NSTextField(labelWithString: L("main.authenticators"))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(title)

        let hintLabel = NSTextField(labelWithString: L("main.drag_to_sort"))
        hintLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hintLabel)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = L("main.authenticators")
        column.width = 260
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 32
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.registerForDraggedTypes([.string])
        scrollView.documentView = tableView
        stack.addArrangedSubview(scrollView)

        let bottomBar = NSStackView()
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 6
        configureSmallButton(addButton, action: #selector(addClicked))
        configureSmallButton(deleteButton, action: #selector(deleteClicked))
        scanQRButton.target = self
        scanQRButton.action = #selector(scanQRCodeClicked)
        scanQRButton.bezelStyle = .rounded
        bottomBar.addArrangedSubview(addButton)
        bottomBar.addArrangedSubview(deleteButton)
        bottomBar.addArrangedSubview(NSView())
        bottomBar.addArrangedSubview(scanQRButton)
        if let spacer = bottomBar.arrangedSubviews.first(where: { type(of: $0) == NSView.self }) {
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        stack.addArrangedSubview(bottomBar)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360)
        ])

        return container
    }

    private func configureSmallButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
    }

    private func makeDetailPane() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let title = NSTextField(labelWithString: L("main.details"))
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        stack.addArrangedSubview(title)

        stack.addArrangedSubview(makeLabeledField(label: L("main.name"), field: nameField))
        stack.addArrangedSubview(makeURLField())

        codeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 32, weight: .semibold)
        expiryLabel.textColor = .secondaryLabelColor
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping

        let codeStack = NSStackView(views: [codeLabel, copyButton, editButton])
        codeStack.orientation = .horizontal
        codeStack.alignment = .centerY
        codeStack.spacing = 10
        copyButton.target = self
        copyButton.action = #selector(copyCodeClicked)
        copyButton.bezelStyle = .rounded
        editButton.target = self
        editButton.action = #selector(editClicked)
        editButton.bezelStyle = .rounded
        stack.addArrangedSubview(codeStack)
        stack.addArrangedSubview(expiryLabel)

        let editActions = NSStackView(views: [saveButton, cancelButton])
        editActions.orientation = .horizontal
        editActions.spacing = 8
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.bezelStyle = .rounded
        stack.addArrangedSubview(editActions)
        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 440)
        ])

        return container
    }

    private func makeLabeledField(label: String, field: NSTextField) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        let labelField = NSTextField(labelWithString: label)
        labelField.textColor = .secondaryLabelColor
        stack.addArrangedSubview(labelField)
        stack.addArrangedSubview(field)
        return stack
    }

    private func makeURLField() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        let labelField = NSTextField(labelWithString: L("main.otpauth_url"))
        labelField.textColor = .secondaryLabelColor
        stack.addArrangedSubview(labelField)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        urlTextView.isRichText = false
        urlTextView.isAutomaticQuoteSubstitutionEnabled = false
        urlTextView.isAutomaticDashSubstitutionEnabled = false
        urlTextView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        urlTextView.textContainer?.widthTracksTextView = true
        urlTextView.isHorizontallyResizable = false
        urlTextView.isVerticallyResizable = true
        urlTextView.autoresizingMask = [.width]
        urlTextView.delegate = self
        scrollView.documentView = urlTextView
        stack.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 440),
            scrollView.heightAnchor.constraint(equalToConstant: 112)
        ])

        return stack
    }

    private func makeSettingsView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let title = NSTextField(labelWithString: L("main.settings"))
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        stack.addArrangedSubview(title)

        let importExportStack = NSStackView()
        importExportStack.orientation = .horizontal
        importExportStack.spacing = 8
        let importButton = NSButton(title: L("main.import"), target: self, action: #selector(importClicked))
        let exportButton = NSButton(title: L("main.export"), target: self, action: #selector(exportClicked))
        [importButton, exportButton].forEach { $0.bezelStyle = .rounded }
        importExportStack.addArrangedSubview(importButton)
        importExportStack.addArrangedSubview(exportButton)
        stack.addArrangedSubview(importExportStack)

        let portStack = NSStackView()
        portStack.orientation = .horizontal
        portStack.alignment = .centerY
        portStack.spacing = 8
        httpPortField.stringValue = DataManager.shared.getHttpServerPort()
        httpPortField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let savePortButton = NSButton(title: L("main.save_port"), target: self, action: #selector(savePortClicked))
        savePortButton.bezelStyle = .rounded
        portStack.addArrangedSubview(NSTextField(labelWithString: L("http.port.label")))
        portStack.addArrangedSubview(httpPortField)
        portStack.addArrangedSubview(savePortButton)
        stack.addArrangedSubview(portStack)

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(toggleLaunchAtLogin)
        launchAtLoginButton.state = LoginItemManager.shared.isEnabled ? .on : .off
        stack.addArrangedSubview(launchAtLoginButton)

        httpAutoStartButton.target = self
        httpAutoStartButton.action = #selector(toggleHttpAutoStart)
        httpAutoStartButton.state = DataManager.shared.getHttpServerAutoStart() ? .on : .off
        stack.addArrangedSubview(httpAutoStartButton)

        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])

        return container
    }

    private func reloadData(selecting tag: String?) {
        entries = DataManager.shared.allAuthEntries()
        tableView.reloadData()

        if let tag = tag, let index = entries.firstIndex(where: { $0.tag == tag }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            populateDetails(for: entries[index])
        } else if !entries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            selectedTag = entries[0].tag
            populateDetails(for: entries[0])
        } else {
            selectedTag = nil
            showEmptyState()
        }
    }

    private func populateDetails(for entry: AuthEntry) {
        nameField.stringValue = entry.tag
        urlTextView.string = entry.url
        updateCode()
        setFormEnabled(false)
        saveButton.isHidden = true
        cancelButton.isHidden = true
        editButton.isHidden = false
        editButton.isEnabled = true
        deleteButton.isEnabled = true
        copyButton.isEnabled = true
        scanQRButton.isEnabled = false
        statusLabel.stringValue = ""
    }

    private func showEmptyState() {
        nameField.stringValue = ""
        urlTextView.string = ""
        codeLabel.stringValue = "--"
        expiryLabel.stringValue = L("main.no_selection")
        statusLabel.stringValue = ""
        setFormEnabled(false)
        saveButton.isHidden = true
        cancelButton.isHidden = true
        editButton.isHidden = true
        deleteButton.isEnabled = false
        copyButton.isEnabled = false
        scanQRButton.isEnabled = false
    }

    private func setFormEnabled(_ enabled: Bool) {
        nameField.isEditable = enabled
        nameField.isSelectable = true
        urlTextView.isEditable = enabled
        urlTextView.isSelectable = true
    }

    private func updateCode() {
        guard let tag = selectedTag, let code = DataManager.shared.verificationCode(for: tag) else {
            codeLabel.stringValue = "--"
            expiryLabel.stringValue = L("main.invalid_code")
            return
        }

        let second = 30 - Calendar(identifier: .gregorian).component(.second, from: Date()) % 30
        codeLabel.stringValue = code
        expiryLabel.stringValue = "\(EXPIRE_TIME_STR)\(second)s"
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCode()
        }
    }

    @objc private func addClicked() {
        formMode = .adding
        selectedTag = nil
        tableView.deselectAll(nil)
        nameField.stringValue = ""
        urlTextView.string = ""
        codeLabel.stringValue = "--"
        expiryLabel.stringValue = L("main.adding")
        statusLabel.stringValue = ""
        setFormEnabled(true)
        saveButton.isHidden = false
        cancelButton.isHidden = false
        editButton.isHidden = true
        copyButton.isEnabled = false
        scanQRButton.isEnabled = true
        nameField.becomeFirstResponder()
    }

    @objc private func editClicked() {
        guard selectedTag != nil else {
            return
        }
        formMode = .editing
        setFormEnabled(true)
        saveButton.isHidden = false
        cancelButton.isHidden = false
        editButton.isHidden = true
        scanQRButton.isEnabled = true
        nameField.becomeFirstResponder()
    }

    @objc private func deleteClicked() {
        guard let tag = selectedTag else {
            return
        }

        let alert = NSAlert()
        alert.messageText = LF("main.delete.confirm", tag)
        alert.addButton(withTitle: L("main.delete"))
        alert.addButton(withTitle: L("main.cancel"))
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            DataManager.shared.removeOTPAuthURL(tag: tag)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "VerifyKeyAdded"), object: nil)
            reloadData(selecting: nil)
        }
    }

    @objc private func saveClicked() {
        let tag = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        urlTextView.string = url

        guard !tag.isEmpty else {
            statusLabel.stringValue = L("main.name.required")
            return
        }
        guard DataManager.shared.isValidOTPAuthURL(url) else {
            statusLabel.stringValue = L("auth.invalid_url")
            return
        }

        switch formMode {
        case .adding:
            DataManager.shared.addOTPAuthURL(tag: tag, url: url)
        case .editing:
            DataManager.shared.updateOTPAuthURL(oldTag: selectedTag ?? tag, newTag: tag, newUrl: url)
        case .viewing:
            return
        }

        formMode = .viewing
        selectedTag = tag
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "VerifyKeyAdded"), object: nil)
        reloadData(selecting: tag)
    }

    @objc private func cancelClicked() {
        formMode = .viewing
        reloadData(selecting: selectedTag)
    }

    @objc private func copyCodeClicked() {
        guard let tag = selectedTag, let code = DataManager.shared.verificationCode(for: tag) else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        statusLabel.stringValue = L("main.copied")
    }

    @objc private func scanQRCodeClicked() {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = NSImage.imageTypes
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true

        guard openPanel.runModal() == .OK,
              let url = openPanel.url,
              let ciImage = CIImage(contentsOf: url),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow]),
              let result = detector.features(in: ciImage).last as? CIQRCodeFeature,
              let message = result.messageString else {
            statusLabel.stringValue = L("main.scan_failed")
            return
        }

        urlTextView.string = message.trimmingCharacters(in: .whitespacesAndNewlines)
        updateNameFromURLIfNeeded(force: true)
    }

    private func updateNameFromURLIfNeeded(force: Bool = false) {
        let url = urlTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        urlTextView.string = url

        guard (force || formMode == .adding),
              (force || nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
              let otpInfo = OTPAuthURLParser(url) else {
            return
        }

        nameField.stringValue = otpInfo.displayName
    }

    @objc private func importClicked() {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["secrets"]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        if openPanel.runModal() == .OK, let url = openPanel.url {
            let count = DataManager.shared.importData(dist: url)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "VerifyKeyAdded"), object: nil)
            reloadData(selecting: selectedTag)
            statusLabel.stringValue = LF("import.success", count)
        }
    }

    @objc private func exportClicked() {
        let savePanel = NSSavePanel()
        savePanel.title = L("export.title")
        savePanel.nameFieldStringValue = "GoldenPassport.secrets"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            DataManager.shared.exportData(dist: url)
        }
    }

    @objc private func savePortClicked() {
        let port = httpPortField.integerValue
        guard port > 0 && port < 65535 else {
            statusLabel.stringValue = L("http.port.invalid")
            return
        }

        DataManager.shared.saveHttpServerPort(port: "\(port)")
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "HTTPServerPortChanged"), object: nil)
        statusLabel.stringValue = L("http.port.updated")
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LoginItemManager.shared.setEnabled(launchAtLoginButton.state == .on)
        } catch {
            launchAtLoginButton.state = LoginItemManager.shared.isEnabled ? .on : .off
            statusLabel.stringValue = LF("launch_at_login.failed", "\(error)")
        }
    }

    @objc private func toggleHttpAutoStart() {
        DataManager.shared.saveHttpServerAutoStart(auto: httpAutoStartButton.state == .on)
    }
}
