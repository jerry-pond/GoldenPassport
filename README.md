# GoldenPassport

[简体中文](README.zh-CN.md) | English

GoldenPassport is a native macOS authenticator app for managing OTPAuth / Google Authenticator verification codes.

This repository is a fork of [stanzhai/GoldenPassport](https://github.com/stanzhai/GoldenPassport). This fork adds a full main window for managing authenticators, keeps the original menu bar quick-copy workflow, and updates the project to build with Xcode and Swift Package Manager.

## Screenshots

![main](screenshot/main.png)

![add](screenshot/add-window.png)

![edit](screenshot/edit.png)

![restful-api](screenshot/restful-api.png)

## Features

- Recognize OTPAuth URLs from QR code images
- Manage authenticators in a full macOS app window
- Manage authentication codes from the macOS menu bar
- Edit existing authentication entries, including name and OTPAuth URL
- Support English and Simplified Chinese UI
- Launch automatically at login
- Copy verification codes from the status menu
- Fill verification codes with global hotkeys: `Shift+Cmd+[0-9]`
- Export and import authentication codes
- Provide a local REST API for reading verification codes from scripts

## Download

Download the latest build from this fork's [GitHub Releases](https://github.com/jerry-pond/GoldenPassport/releases) page.

The current release provides separate unsigned builds for:

- Apple Silicon: `GoldenPassport-arm64-unsigned.zip`
- Intel Mac: `GoldenPassport-x86_64-unsigned.zip`

Unzip the package for your Mac, then move `GoldenPassport.app` to `/Applications`.

The release packages are ad-hoc signed and do not use an Apple Developer ID. On first launch, macOS may require opening the app from Finder with right click > Open, or allowing it in System Settings > Privacy & Security.

## Usage

1. Start `GoldenPassport.app`.
2. Use the main window to add, edit, delete, import, export, and copy verification codes.
3. Use the menu bar item for quick access and fast copying.
4. Use `Shift+Cmd+[0-9]` to fill a verification code directly.

### Main Window

The main window is the primary management surface:

- Select an authenticator from the list to view its current code and OTPAuth URL.
- Click `Add` to create a new authenticator.
- Click `Edit` to update the selected authenticator's name or OTPAuth URL.
- Click `Delete` to remove the selected authenticator.
- Use `Import`, `Export`, launch-at-login, and HTTP port settings from the same window.

The menu bar remains available for quick copy and hotkey workflows.

## REST API

GoldenPassport can expose verification codes through a local HTTP API:

```bash
# You can inspect available routes from http://localhost:17304/
code=$(curl 'http://localhost:17304/code/test@example.com')
echo "$code"
```

## Building

This fork uses Swift Package Manager for dependencies. CocoaPods is no longer required.

1. Install the latest stable Xcode.
2. Open `GoldenPassport.xcodeproj` with Xcode.
3. Let Xcode resolve Swift Package dependencies.
4. Build the `GoldenPassport` scheme.

Command-line build example:

```bash
xcodebuild \
  -project GoldenPassport.xcodeproj \
  -scheme GoldenPassport \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

## Changes In This Fork

- Forked from [stanzhai/GoldenPassport](https://github.com/stanzhai/GoldenPassport)
- Added a full main app window for authenticator management
- Added edit mode for existing authentication entries
- Added edit icon assets and menu state handling
- Added English and Simplified Chinese app localization
- Added Simplified Chinese README
- Added launch-at-login support
- Migrated dependency management from CocoaPods to Swift Package Manager
- Added `Package.resolved` to lock SwiftPM dependency resolution
- Updated build and release packaging for separate `arm64` and `x86_64` macOS apps

## Resources

- [Original GoldenPassport repository](https://github.com/stanzhai/GoldenPassport)
- [Swift Resources](https://developer.apple.com/swift/resources/)
- [Swift Package Manager](https://www.swift.org/package-manager/)
- [google-authenticator](https://github.com/google/google-authenticator)
- [swifter](https://github.com/httpswift/swifter)

## Todo

- Continue improving release automation
