//
//  AppConfiguration.swift
//  Coheremote
//
//  アプリ設定の保存と読み込み
//

import Foundation
import Combine
import Security

enum ConnectionMode: String, Codable, CaseIterable, Identifiable {
    case localVM = "localVM"
    case network = "network"

    var id: String { rawValue }
}

struct AppConfiguration: Codable {
    var connectionMode: ConnectionMode
    var rdpFilePath: String
    var iconImagePath: String
    // Local VM fields
    var vmPath: String
    var vmEncryptionPassword: String
    // Network fields
    var hostName: String
    var macAddress: String
    // Common fields
    var windowsUsername: String
    var windowsPassword: String
    var closeVMOnExit: Bool
    var shutdownOnExit: Bool
    var overlayIcon: Bool
    var enableStartMenu: Bool
    // RemoteApp injection
    var enableRemoteApp: Bool
    var remoteAppName: String
    var remoteAppProgram: String

    init() {
        self.connectionMode = .localVM
        self.rdpFilePath = ""
        self.iconImagePath = ""
        self.vmPath = ""
        self.vmEncryptionPassword = ""
        self.hostName = ""
        self.macAddress = ""
        self.windowsUsername = ""
        self.windowsPassword = ""
        self.closeVMOnExit = false
        self.shutdownOnExit = false
        self.overlayIcon = false
        self.enableStartMenu = true
        self.enableRemoteApp = false
        self.remoteAppName = ""
        self.remoteAppProgram = ""
    }

    // パスワードフィールドはKeychainで管理するためCodable対象外
    enum CodingKeys: String, CodingKey {
        case connectionMode, rdpFilePath, iconImagePath, vmPath
        case hostName, macAddress, windowsUsername
        case closeVMOnExit, shutdownOnExit, overlayIcon, enableStartMenu
        case enableRemoteApp, remoteAppName, remoteAppProgram
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        connectionMode = try container.decodeIfPresent(ConnectionMode.self, forKey: .connectionMode) ?? .localVM
        rdpFilePath = try container.decode(String.self, forKey: .rdpFilePath)
        iconImagePath = try container.decode(String.self, forKey: .iconImagePath)
        vmPath = try container.decode(String.self, forKey: .vmPath)
        vmEncryptionPassword = ""
        hostName = try container.decodeIfPresent(String.self, forKey: .hostName) ?? ""
        macAddress = try container.decodeIfPresent(String.self, forKey: .macAddress) ?? ""
        windowsUsername = try container.decode(String.self, forKey: .windowsUsername)
        windowsPassword = ""
        closeVMOnExit = try container.decode(Bool.self, forKey: .closeVMOnExit)
        shutdownOnExit = try container.decode(Bool.self, forKey: .shutdownOnExit)
        overlayIcon = try container.decodeIfPresent(Bool.self, forKey: .overlayIcon) ?? false
        enableStartMenu = try container.decodeIfPresent(Bool.self, forKey: .enableStartMenu) ?? true
        enableRemoteApp = try container.decodeIfPresent(Bool.self, forKey: .enableRemoteApp) ?? false
        remoteAppName = try container.decodeIfPresent(String.self, forKey: .remoteAppName) ?? ""
        remoteAppProgram = try container.decodeIfPresent(String.self, forKey: .remoteAppProgram) ?? ""
    }
}

class ConfigurationManager: ObservableObject {
    @Published var config = AppConfiguration()

    private let userDefaultsKey = "lastUsedConfiguration"
    private let keychainService = "Coheremote-Builder"

    init() {
        loadConfiguration()
    }

    func saveConfiguration() {
        do {
            let encoded = try JSONEncoder().encode(config)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        } catch {
            print("[Coheremote] Failed to save configuration: \(error)")
        }
        savePasswordToKeychain(account: "vmEncryption", password: config.vmEncryptionPassword)
        savePasswordToKeychain(account: "windowsPassword", password: config.windowsPassword)
    }

    func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            config = try JSONDecoder().decode(AppConfiguration.self, from: data)
        } catch {
            print("[Coheremote] Failed to load configuration: \(error)")
        }
        config.vmEncryptionPassword = loadPasswordFromKeychain(account: "vmEncryption") ?? ""
        config.windowsPassword = loadPasswordFromKeychain(account: "windowsPassword") ?? ""
    }

    // MARK: - Keychain

    private func savePasswordToKeychain(account: String, password: String) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard !password.isEmpty, let data = password.data(using: .utf8) else { return }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Coheremote] Failed to save password to Keychain (account: \(account), status: \(status))")
        }
    }

    private func loadPasswordFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    func isValid() -> Bool {
        let baseValid = !config.rdpFilePath.isEmpty &&
                        !config.vmPath.isEmpty &&
                        !config.windowsUsername.isEmpty
        if config.enableRemoteApp {
            return baseValid && !config.remoteAppProgram.isEmpty
        }
        return baseValid
    }
}
