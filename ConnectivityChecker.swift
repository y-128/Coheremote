//
//  ConnectivityChecker.swift
//  Coheremote
//
//  ネットワーク接続性チェック（Ping）
//

import Foundation

class ConnectivityChecker {

    enum CheckError: LocalizedError {
        case timeout
        case unreachable(String)

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "Host connectivity check timed out."
            case .unreachable(let host):
                return "Host \(host) is unreachable."
            }
        }
    }

    /// Check if a host is reachable using ping (single packet, with timeout)
    static func isReachable(host: String, timeoutSeconds: Int = 3) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                process.arguments = ["-c", "1", "-W", "\(timeoutSeconds * 1000)", host]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Wait for a host to become reachable, retrying with interval
    static func waitForHost(
        host: String,
        timeoutSeconds: Int = 120,
        retryInterval: TimeInterval = 3
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        while Date() < deadline {
            if await isReachable(host: host, timeoutSeconds: 3) {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
        }

        return false
    }
}
