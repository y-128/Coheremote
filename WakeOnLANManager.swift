//
//  WakeOnLANManager.swift
//  Coheremote
//
//  Wake-on-LAN マジックパケット送信
//

import Foundation
import Network

class WakeOnLANManager {

    enum WoLError: LocalizedError {
        case invalidMACAddress
        case sendFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidMACAddress:
                return "Invalid MAC address format. Use XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX."
            case .sendFailed(let reason):
                return "Failed to send WoL packet: \(reason)"
            }
        }
    }

    /// Parse a MAC address string into 6 bytes
    static func parseMACAddress(_ mac: String) throws -> [UInt8] {
        let cleaned = mac
            .replacingOccurrences(of: "-", with: ":")
            .trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":")
        guard parts.count == 6 else { throw WoLError.invalidMACAddress }

        var bytes: [UInt8] = []
        for part in parts {
            guard let byte = UInt8(part, radix: 16) else {
                throw WoLError.invalidMACAddress
            }
            bytes.append(byte)
        }
        return bytes
    }

    /// Build a WoL magic packet: 6 bytes of 0xFF followed by MAC address repeated 16 times
    static func buildMagicPacket(macBytes: [UInt8]) -> Data {
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }
        return packet
    }

    /// Send a Wake-on-LAN magic packet to the broadcast address
    static func wake(macAddress: String, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let macBytes = try parseMACAddress(macAddress)
            let packet = buildMagicPacket(macBytes: macBytes)

            let connection = NWConnection(
                host: .ipv4(.broadcast),
                port: 9,
                using: .udp
            )

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: packet, completion: .contentProcessed { error in
                        connection.cancel()
                        if let error = error {
                            completion(.failure(WoLError.sendFailed(error.localizedDescription)))
                        } else {
                            completion(.success(()))
                        }
                    })
                case .failed(let error):
                    connection.cancel()
                    completion(.failure(WoLError.sendFailed(error.localizedDescription)))
                default:
                    break
                }
            }

            connection.start(queue: .global())
        } catch {
            completion(.failure(error))
        }
    }

    /// Async wrapper for wake
    static func wake(macAddress: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            wake(macAddress: macAddress) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
