//
//  RDPManager.swift
//  Coheremote
//
//  RDPファイルの設定管理
//

import Foundation
import AppKit

class RDPManager {
    /// RDPファイルにユーザー名とパスワード設定を追加（バイナリレベルでBOM・改行を保持）
    static func modifyRDPFile(
        originalPath: String,
        username: String
    ) -> Data? {
        guard let rawData = FileManager.default.contents(atPath: originalPath) else {
            return nil
        }

        // UTF-8 BOMの検出と保持
        let bom = Data([0xEF, 0xBB, 0xBF])
        let hasBOM = rawData.starts(with: bom)
        let textData = hasBOM ? rawData.dropFirst(3) : rawData[...]

        guard let content = String(data: Data(textData), encoding: .utf8) else {
            return nil
        }

        // RDPファイルの改行コードを検出して保持（\r\n が標準）
        let lineEnding = content.contains("\r\n") ? "\r\n" : "\n"
        var lines = content.components(separatedBy: lineEnding)

        // 末尾の空行を除去（分割で生じる空要素）
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }

        var hasUsername = false
        var hasPromptForCredentials = false

        // 既存の設定を更新
        for i in 0..<lines.count {
            if lines[i].hasPrefix("username:s:") && !username.isEmpty {
                lines[i] = "username:s:\(username)"
                hasUsername = true
            } else if lines[i].hasPrefix("prompt for credentials:i:") {
                lines[i] = "prompt for credentials:i:0"
                hasPromptForCredentials = true
            }
        }

        // 存在しない場合は追加
        if !hasUsername && !username.isEmpty {
            lines.append("username:s:\(username)")
        }
        if !hasPromptForCredentials {
            lines.append("prompt for credentials:i:0")
        }

        // 末尾にも改行を付与（Windows標準）
        let joined = lines.joined(separator: lineEnding) + lineEnding

        // BOM + コンテンツのDataを構築
        var result = Data()
        if hasBOM {
            result.append(bom)
        }
        if let textBytes = joined.data(using: .utf8) {
            result.append(textBytes)
        }
        return result
    }
    
    /// 修正されたRDPファイルを一時ディレクトリに保存
    static func createModifiedRDPFile(
        originalPath: String,
        username: String
    ) -> URL? {
        guard let modifiedData = modifyRDPFile(
            originalPath: originalPath,
            username: username
        ) else {
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory
        let filename = (originalPath as NSString).lastPathComponent
        let tempURL = tempDir.appendingPathComponent(filename)

        do {
            try modifiedData.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing modified RDP file: \(error)")
            return nil
        }
    }
    
    /// RDPファイルをWindows Appで開く
    static func openRDP(at path: String) -> Bool {
        let workspace = NSWorkspace.shared
        let url = URL(fileURLWithPath: path)
        
        // Windows App（旧Microsoft Remote Desktop）で開く
        // 互換性のため両方のパスをチェック
        let windowsAppURL = URL(fileURLWithPath: "/Applications/Windows App.app")
        let legacyRDPAppURL = URL(fileURLWithPath: "/Applications/Microsoft Remote Desktop.app")
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        // 新しいWindows Appが存在する場合はそちらを優先
        let appURL = FileManager.default.fileExists(atPath: windowsAppURL.path) ? windowsAppURL : legacyRDPAppURL
        
        workspace.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error = error {
                print("Error opening RDP file: \(error)")
            }
        }
        
        return true
    }
}
