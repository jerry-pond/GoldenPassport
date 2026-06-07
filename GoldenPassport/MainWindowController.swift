import Cocoa

final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
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
    private let urlField = NSTextField()
    private let codeLabel = NSTextField(labelWithString: "")
    private let expiryLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let httpPortField = NSTextField()
    private let launchAtLoginButton = NSButton(checkboxWithTitle: L("menu.launch_at_login"), target: nil, action: nil)
    private let httpAutoStartButton = NSButton(checkboxWithTitle: L("menu.http.auto_start"), target: nil, action: nil)

    private let addButton = NSButton(title: L("main.add"), target: nil, action: nil)
    private let editButton = NSButton(title: L("main.edit"), target: nil, action: nil)
    private let deleteButton = NSButton(title: L("main.delete"), target: nil, action: nil)
    private let saveButton = NSButton(title: L("main.save"), target: nil, action: nil)
    private let cancelButton = NSButton(title: L("main.cancel"), target: nil, action: nil)
    private let copyButton = NSButton(title: L("main.copy_code"), target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GoldenPassport"
        window.minSize = NSSize(width: 820, height: 500)
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

    private func setupUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let toolbar = makeToolbar()
        let body = makeBody()

        root.addArrangedSubview(toolbar)
        root.addArrangedSubview(body)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func makeToolbar() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        configureToolbarButton(addButton, action: #selector(addClicked))
        configureToolbarButton(editButton, action: #selector(editClicked))
        configureToolbarButton(deleteButton, action: #selector(deleteClicked))

        let importButton = NSButton(title: L("main.import"), target: self, action: #selector(importClicked))
        let exportButton = NSButton(title: L("main.export"), target: self, action: #selector(exportClicked))
        let hideWindowButton = NSButton(title: L("main.hide_window"), target: self, action: #selector(hideWindowClicked))

        [importButton, exportButton, hideWindowButton].forEach { button in
            button.bezelStyle = .rounded
        }

        stack.addArrangedSubview(addButton)
        stack.addArrangedSubview(editButton)
        stack.addArrangedSubview(deleteButton)
        stack.addArrangedSubview(NSView())
        stack.addArrangedSubview(importButton)
        stack.addArrangedSubview(exportButton)
        stack.addArrangedSubview(hideWindowButton)

        if let spacer = stack.arrangedSubviews.first(where: { type(of: $0) == NSView.self }) {
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func configureToolbarButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
    }

    private func makeBody() -> NSView {
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin

        let listPane = makeListPane()
        let detailsPane = makeDetailsPane()
        split.addArrangedSubview(listPane)
        split.addArrangedSubview(detailsPane)

        listPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        detailsPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 520).isActive = true
        return split
    }

    private func makeListPane() -> NSView {
        let container = NSView()
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        container.addSubview(scrollView)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = L("main.authenticators")
        column.width = 260
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 30
        tableView.usesAlternatingRowBackgroundColors = true
        scrollView.documentView = tableView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return container
    }

    private func makeDetailsPane() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let title = NSTextField(labelWithString: L("main.details"))
        title.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        stack.addArrangedSubview(title)

        stack.addArrangedSubview(makeLabeledField(label: L("main.name"), field: nameField))
        stack.addArrangedSubview(makeLabeledField(label: L("main.otpauth_url"), field: urlField))

        codeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 30, weight: .semibold)
        expiryLabel.textColor = .secondaryLabelColor
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping

        let codeStack = NSStackView(views: [codeLabel, copyButton])
        codeStack.orientation = .horizontal
        codeStack.alignment = .centerY
        codeStack.spacing = 12
        copyButton.target = self
        copyButton.action = #selector(copyCodeClicked)
        copyButton.bezelStyle = .rounded
        stack.addArrangedSubview(codeStack)
        stack.addArrangedSubview(expiryLabel)

        let actionStack = NSStackView(views: [saveButton, cancelButton])
        actionStack.orientation = .horizontal
        actionStack.spacing = 8
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.bezelStyle = .rounded
        stack.addArrangedSubview(actionStack)

        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeSettingsPane())
        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            urlField.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
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

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func makeSettingsPane() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let title = NSTextField(labelWithString: L("main.settings"))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(title)

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

        return stack
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
        urlField.stringValue = entry.url
        updateCode()
        setFormEnabled(false)
        saveButton.isHidden = true
        cancelButton.isHidden = true
        editButton.isEnabled = true
        deleteButton.isEnabled = true
        copyButton.isEnabled = true
        statusLabel.stringValue = ""
    }

    private func showEmptyState() {
        nameField.stringValue = ""
        urlField.stringValue = ""
        codeLabel.stringValue = "--"
        expiryLabel.stringValue = L("main.no_selection")
        statusLabel.stringValue = ""
        setFormEnabled(false)
        saveButton.isHidden = true
        cancelButton.isHidden = true
        editButton.isEnabled = false
        deleteButton.isEnabled = false
        copyButton.isEnabled = false
    }

    private func setFormEnabled(_ enabled: Bool) {
        nameField.isEditable = enabled
        urlField.isEditable = enabled
        nameField.isSelectable = true
        urlField.isSelectable = true
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
        urlField.stringValue = ""
        codeLabel.stringValue = "--"
        expiryLabel.stringValue = L("main.adding")
        statusLabel.stringValue = ""
        setFormEnabled(true)
        saveButton.isHidden = false
        cancelButton.isHidden = false
        copyButton.isEnabled = false
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
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

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

    @objc private func hideWindowClicked() {
        window?.orderOut(nil)
    }
}
