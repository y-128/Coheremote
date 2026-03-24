//
//  VMwareManager.swift
//  Coheremote
//
//  VMware Fusion制御
//

import Foundation

enum VMState {
    case running
    case suspended
    case poweredOff
    case unknown
}

class VMwareManager {
    static let shared = VMwareManager()
    
    private let vmrunPath = "/Applications/VMware Fusion.app/Contents/Public/vmrun"
    
    private init() {}
    
    /// VMXファイルのパスを取得（.vmwarevmバンドルの場合は内部のvmxを探す）
    func resolveVMXPath(from path: String) -> String? {
        if path.hasSuffix(".vmx") {
            return path
        } else if path.hasSuffix(".vmwarevm") {
            // バンドル内のvmxファイルを検索
            let fileManager = FileManager.default
            guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
                return nil
            }
            
            for file in contents where file.hasSuffix(".vmx") {
                return (path as NSString).appendingPathComponent(file)
            }
        }
        return nil
    }
    
    /// VMの現在の状態を取得
    func getVMState(vmxPath: String) async -> VMState {
        let result = await runCommand(arguments: ["list"])
        
        guard result.success, let output = result.output else {
            return .unknown
        }
        
        // vmrun listの出力から該当VMを探す
        if output.contains(vmxPath) {
            return .running
        }
        
        // 実行中でない場合、サスペンドかパワーオフか判定
        // （実際のファイルシステムでvmemファイルの存在を確認）
        let vmemPath = vmxPath.replacingOccurrences(of: ".vmx", with: ".vmem")
        if FileManager.default.fileExists(atPath: vmemPath) {
            return .suspended
        }
        
        return .poweredOff
    }
    
    /// VMを起動
    /// NOTE: vmrun does not support passing passwords via stdin or file.
    /// The -vp flag exposes the password in process arguments visible to
    /// other processes under the same user. This is a known vmrun limitation.
    func startVM(vmxPath: String, encryptionPassword: String? = nil) async -> Bool {
        var arguments = ["-T", "fusion"]

        if let password = encryptionPassword, !password.isEmpty {
            arguments.append(contentsOf: ["-vp", password])
        }
        
        arguments.append(contentsOf: ["start", vmxPath, "nogui"])
        
        let result = await runCommand(arguments: arguments)
        return result.success
    }
    
    /// VMをサスペンド
    func suspendVM(vmxPath: String) async -> Bool {
        let result = await runCommand(arguments: ["suspend", vmxPath])
        return result.success
    }
    
    /// VMをシャットダウン
    func stopVM(vmxPath: String) async -> Bool {
        let result = await runCommand(arguments: ["stop", vmxPath, "soft"])
        return result.success
    }
    
    /// VMの準備が整うまで待機
    func waitForVMReady(vmxPath: String, timeout: TimeInterval = 60) async -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let state = await getVMState(vmxPath: vmxPath)
            if state == .running {
                // さらに少し待機してゲストOSが完全に起動するのを待つ
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        return false
    }
    
    // MARK: - Private Helper
    
    private func runCommand(arguments: [String]) async -> (success: Bool, output: String?) {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: vmrunPath)
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()

                // パイプバッファのデッドロックを防ぐため、先にデータを読み取る
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(data: data, encoding: .utf8)

                let success = process.terminationStatus == 0
                continuation.resume(returning: (success, output))
            } catch {
                continuation.resume(returning: (false, nil))
            }
        }
    }
}
