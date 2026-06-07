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
