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

    /// ラッパーアプリをビルド
    static func buildApp(
        appName: String,
        config: AppConfiguration,
        savePath: URL
    ) async throws {
        let appBundle = savePath.appendingPathComponent("\(appName).app")
        let contentsDir = appBundle.appendingPathComponent("Contents")
        let macOSDir = contentsDir.appendingPathComponent("MacOS")
        let resourcesDir = contentsDir.appendingPathComponent("Resources")

        // ディレクトリ構造を作成
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: macOSDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        // Info.plistを作成
        try createInfoPlist(appName: appName, at: contentsDir)

        // アイコンを変換してコピー
        if !config.iconImagePath.isEmpty {
            try await convertAndCopyIcon(from: config.iconImagePath, to: resourcesDir)
        }

        // 修正されたRDPファイルをコピー
        let rdpDestination = resourcesDir.appendingPathComponent("app.rdp")
        if let modifiedData = RDPManager.modifyRDPFile(
            originalPath: config.rdpFilePath,
            username: config.windowsUsername
        ) {
            try modifiedData.write(to: rdpDestination)
        }

        // VM暗号化パスワードをKeychainに保存
        if !config.vmEncryptionPassword.isEmpty {
            try savePasswordToKeychain(
                appName: appName,
                password: config.vmEncryptionPassword
            )
        }

        // ラッパーアプリのバイナリを生成
        try createWrapperBinary(
            appName: appName,
            config: config,
            at: macOSDir
        )
    }

    // MARK: - Private Helpers

    private static func savePasswordToKeychain(appName: String, password: String) throws {
        let service = "Coheremote-\(appName)"
        let account = "vmEncryption"

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
            "CFBundleIdentifier": "com.coheremote.\(appName.replacingOccurrences(of: " ", with: ""))",
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

    private static func convertAndCopyIcon(from sourcePath: String, to resourcesDir: URL) async throws {
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
        let vmxPath = VMwareManager.shared.resolveVMXPath(from: config.vmPath) ?? config.vmPath
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
            .replacingOccurrences(of: "{{VMX_PATH}}", with: esc(vmxPath))
            .replacingOccurrences(of: "{{KEYCHAIN_SERVICE}}", with: esc("Coheremote-\(appName)"))
            .replacingOccurrences(of: "{{CLOSE_ON_EXIT}}", with: config.closeVMOnExit ? "true" : "false")
            .replacingOccurrences(of: "{{SHUTDOWN_ON_EXIT}}", with: config.shutdownOnExit ? "true" : "false")
            .replacingOccurrences(of: "{{LOG_NAME}}", with: esc(safeName))

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
