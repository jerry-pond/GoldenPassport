# GoldenPassport

简体中文 | [English](README.md)

GoldenPassport 是一个原生 macOS 验证码管理工具，用于管理 OTPAuth / Google Authenticator 验证码。

本仓库 fork 自 [stanzhai/GoldenPassport](https://github.com/stanzhai/GoldenPassport)。当前 fork 保留了原有菜单栏工作流，新增了已有认证信息的编辑模式，并将项目更新为使用 Xcode 和 Swift Package Manager 构建。

## 截图

![main](screenshot/main.png)

![add](screenshot/add-window.png)

![edit](screenshot/edit.png)

![restful-api](screenshot/restful-api.png)

## 功能

- 从二维码图片识别 OTPAuth URL
- 通过 macOS 菜单栏管理验证码
- 编辑已有认证信息，包括名称和 OTPAuth URL
- 支持英文和简体中文界面
- 支持开机启动
- 从状态栏菜单复制验证码
- 使用全局快捷键 `Shift+Cmd+[0-9]` 直接填入验证码
- 导出和导入认证信息
- 提供本地 REST API，方便脚本读取验证码

## 下载

请从本 fork 的 [GitHub Releases](https://github.com/jerry-pond/GoldenPassport/releases) 页面下载最新版本。

当前版本分别提供两个未使用开发者签名的安装包：

- Apple Silicon：`GoldenPassport-arm64-unsigned.zip`
- Intel Mac：`GoldenPassport-x86_64-unsigned.zip`

解压适合你 Mac 架构的包，然后将 `GoldenPassport.app` 移动到 `/Applications`。

这些发布包使用 ad-hoc 本地签名，没有 Apple Developer ID。首次启动时，macOS 可能要求你在 Finder 中右键选择“打开”，或在“系统设置 > 隐私与安全性”中允许打开。

## 使用

1. 启动 `GoldenPassport.app`。
2. 从状态栏菜单添加 OTPAuth URL，或导入已有数据。
3. 点击认证菜单项复制当前验证码。
4. 使用 `Shift+Cmd+[0-9]` 直接填入验证码。

### 编辑模式

本 fork 新增了已有认证信息的编辑模式：

1. 点击 `编辑` 菜单项。
2. 从状态栏菜单中选择要编辑的认证信息。
3. 修改名称或 OTPAuth URL，然后保存。
4. 点击 `完成编辑` 退出编辑模式。

## REST API

GoldenPassport 可以通过本地 HTTP API 暴露验证码：

```bash
# 可通过 http://localhost:17304/ 查看可用路由
code=$(curl 'http://localhost:17304/code/test@example.com')
echo "$code"
```

## 构建

本 fork 使用 Swift Package Manager 管理依赖，不再需要 CocoaPods。

1. 安装最新稳定版 Xcode。
2. 使用 Xcode 打开 `GoldenPassport.xcodeproj`。
3. 等待 Xcode 自动解析 Swift Package 依赖。
4. 构建 `GoldenPassport` scheme。

命令行构建示例：

```bash
xcodebuild \
  -project GoldenPassport.xcodeproj \
  -scheme GoldenPassport \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

## 本 fork 的主要变更

- Fork 自 [stanzhai/GoldenPassport](https://github.com/stanzhai/GoldenPassport)
- 新增已有认证信息的编辑模式
- 新增编辑图标资源和菜单状态处理
- 新增英文和简体中文界面本地化
- 新增简体中文 README
- 新增开机启动支持
- 从 CocoaPods 迁移到 Swift Package Manager
- 增加 `Package.resolved`，锁定 SwiftPM 依赖解析
- 更新发布构建流程，分别提供 `arm64` 和 `x86_64` macOS app

## 资源

- [原始 GoldenPassport 仓库](https://github.com/stanzhai/GoldenPassport)
- [Swift Resources](https://developer.apple.com/swift/resources/)
- [Swift Package Manager](https://www.swift.org/package-manager/)
- [google-authenticator](https://github.com/google/google-authenticator)
- [swifter](https://github.com/httpswift/swifter)

## Todo

- 继续完善发布自动化
