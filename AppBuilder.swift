//
//  AppBuilder.swift
//  Coheremote
//
//  ラッパーアプリのビルダー
//

import Foundation
import AppKit
import Security

class AppBuilder {

    /// ファイルシステム安全なアプリ名にサニタイズ
    static func sanitizeAppName(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|\0")
        var cleaned = name.unicodeScalars
            .filter { !forbidden.contains($0) }
            .map { String($0) }
            .joined()
            .trimmingCharacters(in: .whitespaces)
        cleaned = cleaned.replacingOccurrences(of: "..", with: "")
        if cleaned.hasPrefix(".") { cleaned = String(cleaned.dropFirst()) }
        return cleaned.isEmpty ? "App" : cleaned
    }

    /// Bundle ID用に英数字とハイフンのみに制限
    private static func bundleIDComponent(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let result = name.unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
        return result.isEmpty ? "app" : result
    }

    /// ラッパーアプリをビルド
    static func buildApp(
        appName: String,
        config: AppConfiguration,
        savePath: URL
    ) async throws {
        let safeName = sanitizeAppName(appName)
        let appBundle = savePath.appendingPathComponent("\(safeName).app")
        let contentsDir = appBundle.appendingPathComponent("Contents")
        let macOSDir = contentsDir.appendingPathComponent("MacOS")
        let resourcesDir = contentsDir.appendingPathComponent("Resources")

        // ディレクトリ構造を作成
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: macOSDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        // Info.plistを作成
        try createInfoPlist(appName: safeName, at: contentsDir)

        // アイコンを変換してコピー
        if !config.iconImagePath.isEmpty {
            try await convertAndCopyIcon(from: config.iconImagePath, to: resourcesDir, overlay: config.overlayIcon)
        }

        // メニューバーアイコンをコピー（Asset Catalogから書き出し）
        if config.enableStartMenu,
           let img = NSImage(named: "MenuBarIcon"),
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let pngData = rep.representation(using: .png, properties: [:]) {
            let dest = resourcesDir.appendingPathComponent("MenuBarIcon.png")
            try pngData.write(to: dest)
        }

        // 修正されたRDPファイルをコピー
        let rdpDestination = resourcesDir.appendingPathComponent("app.rdp")
        if let modifiedData = RDPManager.modifyRDPFile(
            originalPath: config.rdpFilePath,
            username: config.windowsUsername,
            remoteApp: (config.enableRemoteApp, config.remoteAppName, config.remoteAppProgram)
        ) {
            try modifiedData.write(to: rdpDestination)
        }

        // VM暗号化パスワードをKeychainに保存
        if !config.vmEncryptionPassword.isEmpty {
            try savePasswordToKeychain(
                appName: safeName,
                account: "vmEncryption",
                password: config.vmEncryptionPassword
            )
        }

        // WindowsパスワードをKeychainに保存
        if !config.windowsPassword.isEmpty {
            try savePasswordToKeychain(
                appName: safeName,
                account: "windowsPassword",
                password: config.windowsPassword
            )
        }

        // ラッパーアプリのバイナリを生成
        try createWrapperBinary(
            appName: safeName,
            config: config,
            at: macOSDir
        )
    }

    // MARK: - Private Helpers

    private static func savePasswordToKeychain(appName: String, account: String, password: String) throws {
        let service = "Coheremote-\(appName)"

        // 既存のエントリを削除
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 新しいエントリを追加
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: password.data(using: .utf8)!
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "AppBuilder", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to save password to Keychain (status: \(status))"
            ])
        }
    }

    private static func createInfoPlist(appName: String, at contentsDir: URL) throws {
        let plist: [String: Any] = [
            "CFBundleExecutable": appName,
            "CFBundleIdentifier": "com.coheremote.\(bundleIDComponent(appName))",
            "CFBundleName": appName,
            "CFBundleDisplayName": appName,
            "CFBundleVersion": "1.0",
            "CFBundleShortVersionString": "1.0",
            "CFBundlePackageType": "APPL",
            "CFBundleIconFile": "AppIcon",
            "LSMinimumSystemVersion": "13.0",
            "LSUIElement": false,
            "NSHighResolutionCapable": true
        ]

        let plistURL = contentsDir.appendingPathComponent("Info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: plistURL)
    }

    private static func convertAndCopyIcon(from sourcePath: String, to resourcesDir: URL, overlay: Bool = false) async throws {
        let iconsetURL = resourcesDir.appendingPathComponent("AppIcon.iconset")
        let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")

        // .icoファイルの場合はNSImageでPNGに変換してからsipsに渡す
        var effectivePath = sourcePath
        var tempPNGURL: URL?
        if sourcePath.lowercased().hasSuffix(".ico") {
            let pngURL = resourcesDir.appendingPathComponent("_temp_icon.png")
            try convertICOtoPNG(icoPath: sourcePath, pngPath: pngURL)
            effectivePath = pngURL.path
            tempPNGURL = pngURL
        }

        // オーバーレイ適用
        if overlay {
            let overlaidURL = resourcesDir.appendingPathComponent("_temp_overlaid.png")
            try applyOverlay(to: effectivePath, outputPath: overlaidURL)
            effectivePath = overlaidURL.path
            // 追加の一時ファイルも後で削除
        }

        // iconsetディレクトリを作成
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        // 各サイズのアイコンを生成（macOS標準の基本サイズ）
        let baseSizes = [16, 32, 128, 256, 512]
        for base in baseSizes {
            // 通常版: icon_{base}x{base}.png（baseピクセル）
            let normalPath = iconsetURL.appendingPathComponent("icon_\(base)x\(base).png")
            try await runSips(inputPath: effectivePath, outputPath: normalPath.path, size: base)

            // Retina版: icon_{base}x{base}@2x.png（base*2ピクセル）
            let retinaPath = iconsetURL.appendingPathComponent("icon_\(base)x\(base)@2x.png")
            try await runSips(inputPath: effectivePath, outputPath: retinaPath.path, size: base * 2)
        }

        // iconutilでicnsに変換
        try await runIconutil(iconsetPath: iconsetURL.path, outputPath: icnsURL.path)

        // 一時ファイルの削除
        try? FileManager.default.removeItem(at: iconsetURL)
        if let tempPNGURL { try? FileManager.default.removeItem(at: tempPNGURL) }
        let overlaidTemp = resourcesDir.appendingPathComponent("_temp_overlaid.png")
        try? FileManager.default.removeItem(at: overlaidTemp)
    }

    /// Coheremoteロゴをアイコンの右下にオーバーレイ合成
    private static func applyOverlay(to sourcePath: String, outputPath: URL) throws {
        guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
            throw NSError(domain: "AppBuilder", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load source icon for overlay"
            ])
        }

        // Coheremoteアプリ自身のアイコンをオーバーレイとして使用
        guard let overlayImage = NSApp.applicationIconImage else {
            throw NSError(domain: "AppBuilder", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load Coheremote app icon for overlay"
            ])
        }

        // ソース画像の最大解像度を取得
        guard let bestRep = sourceImage.representations
            .sorted(by: { ($0.pixelsWide * $0.pixelsHigh) > ($1.pixelsWide * $1.pixelsHigh) })
            .first else {
            throw NSError(domain: "AppBuilder", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Source icon has no image representations"
            ])
        }

        let width = bestRep.pixelsWide
        let height = bestRep.pixelsHigh

        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        // ソース画像を描画
        sourceImage.draw(in: NSRect(x: 0, y: 0, width: width, height: height))

        // オーバーレイを右下に配置（アイコンの35%サイズ）
        let overlaySize = Int(Double(min(width, height)) * 0.35)
        let overlayRect = NSRect(
            x: width - overlaySize,
            y: 0,
            width: overlaySize,
            height: overlaySize
        )
        overlayImage.draw(in: overlayRect)

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AppBuilder", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate overlaid icon PNG"
            ])
        }

        try pngData.write(to: outputPath)
    }

    /// .icoファイルをPNGに変換（最大サイズの画像を使用）
    private static func convertICOtoPNG(icoPath: String, pngPath: URL) throws {
        guard let image = NSImage(contentsOfFile: icoPath) else {
            throw NSError(domain: "AppBuilder", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load ICO file"
            ])
        }

        // 最大サイズのimage repを選択
        guard let bestRep = image.representations
            .sorted(by: { ($0.pixelsWide * $0.pixelsHigh) > ($1.pixelsWide * $1.pixelsHigh) })
            .first else {
            throw NSError(domain: "AppBuilder", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "ICO file contains no image representations"
            ])
        }

        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: bestRep.pixelsWide,
            pixelsHigh: bestRep.pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(in: NSRect(x: 0, y: 0, width: bestRep.pixelsWide, height: bestRep.pixelsHigh))
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AppBuilder", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert ICO to PNG"
            ])
        }

        try pngData.write(to: pngPath)
    }

    private static func runSips(inputPath: String, outputPath: String, size: Int) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = [
            "-z", "\(size)", "\(size)",
            inputPath,
            "--out", outputPath
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "AppBuilder", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to resize icon with sips"
            ])
        }
    }

    private static func runIconutil(iconsetPath: String, outputPath: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = [
            "-c", "icns",
            iconsetPath,
            "-o", outputPath
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "AppBuilder", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert icon with iconutil"
            ])
        }
    }

    private static func createWrapperBinary(
        appName: String,
        config: AppConfiguration,
        at macOSDir: URL
    ) throws {
        let vmxPath: String
        if config.connectionMode == .localVM {
            vmxPath = VMwareManager.shared.resolveVMXPath(from: config.vmPath) ?? config.vmPath
        } else {
            vmxPath = ""
        }
        let safeName = appName.replacingOccurrences(of: " ", with: "_")

        // テンプレートを読み込み
        guard let templateURL = Bundle.main.url(forResource: "WrapperTemplate", withExtension: "txt"),
              var source = try? String(contentsOf: templateURL, encoding: .utf8) else {
            throw NSError(domain: "AppBuilder", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Wrapper template not found in app bundle"
            ])
        }

        // Swift文字列リテラル用にエスケープ
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }

        // プレースホルダーを置換
        source = source
            .replacingOccurrences(of: "{{APP_NAME}}", with: esc(appName))
            .replacingOccurrences(of: "{{CONNECTION_MODE}}", with: config.connectionMode.rawValue)
            .replacingOccurrences(of: "{{VMX_PATH}}", with: esc(vmxPath))
            .replacingOccurrences(of: "{{KEYCHAIN_SERVICE}}", with: esc("Coheremote-\(appName)"))
            .replacingOccurrences(of: "{{CLOSE_ON_EXIT}}", with: config.closeVMOnExit ? "true" : "false")
            .replacingOccurrences(of: "{{SHUTDOWN_ON_EXIT}}", with: config.shutdownOnExit ? "true" : "false")
            .replacingOccurrences(of: "{{LOG_NAME}}", with: esc(safeName))
            .replacingOccurrences(of: "{{HOST_NAME}}", with: esc(config.hostName))
            .replacingOccurrences(of: "{{MAC_ADDRESS}}", with: esc(config.macAddress))
            .replacingOccurrences(of: "{{ENABLE_START_MENU}}", with: config.enableStartMenu ? "true" : "false")
            .replacingOccurrences(of: "{{WINDOWS_USERNAME}}", with: esc(config.windowsUsername))

        // 一時ファイルに書き出し
        let tempSource = macOSDir.appendingPathComponent("_wrapper.swift")
        try source.write(to: tempSource, atomically: true, encoding: .utf8)

        // swiftcでコンパイル
        let binaryURL = macOSDir.appendingPathComponent(appName)
        let compiler = Process()
        let errPipe = Pipe()
        compiler.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        compiler.arguments = ["-swift-version", "5", "-o", binaryURL.path, tempSource.path]
        compiler.standardError = errPipe
        compiler.standardOutput = FileHandle.nullDevice
        try compiler.run()
        compiler.waitUntilExit()

        // ソースファイル削除
        try? FileManager.default.removeItem(at: tempSource)

        guard compiler.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? ""
            throw NSError(domain: "AppBuilder", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Wrapper compilation failed: \(errMsg)"
            ])
        }
    }
}
