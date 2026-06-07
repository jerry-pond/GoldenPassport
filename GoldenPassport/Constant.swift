//
//  Constant.swift
//  GoldenPassport
//
//  Created by StanZhai on 2017/2/26.
//  Copyright © 2017年 StanZhai. All rights reserved.
//

import Foundation

func L(_ key: String) -> String {
    return NSLocalizedString(key, tableName: "I18n", comment: "")
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    return String(format: L(key), arguments: arguments)
}

var EXPIRE_TIME_STR: String { L("status.expire_time") }

var COPY_AUTH_CODE_STR: String { L("status.copy_code.tooltip") }
var DELETE_VERIFY_KEY_STR: String { L("status.delete_key.tooltip") }

var DONE_REMOVE_STR: String { L("menu.delete.done") }
var REMOVE_STR: String { L("menu.delete") }

let DEFAULT_HTTP_PORT = 17304

final class LoginItemManager {
    static let shared = LoginItemManager()

    private let label = "site.stanzhai.GoldenPassport"

    private init() {}

    var isEnabled: Bool {
        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try installLaunchAgent()
        } else {
            try removeLaunchAgent()
        }
    }

    private func installLaunchAgent() throws {
        guard let executablePath = Bundle.main.executablePath else {
            return
        }

        try FileManager.default.createDirectory(
            at: launchAgentsDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private func removeLaunchAgent() throws {
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
        }
    }

    private var launchAgentsDirectoryURL: URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
    }

    private var launchAgentURL: URL {
        return launchAgentsDirectoryURL.appendingPathComponent("\(label).plist")
    }
}
