//
//  AppConfiguration.swift
//  Coheremote
//
//  アプリ設定の保存と読み込み
//

import Foundation
import Combine

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        connectionMode = try container.decodeIfPresent(ConnectionMode.self, forKey: .connectionMode) ?? .localVM
        rdpFilePath = try container.decode(String.self, forKey: .rdpFilePath)
        iconImagePath = try container.decode(String.self, forKey: .iconImagePath)
        vmPath = try container.decode(String.self, forKey: .vmPath)
        vmEncryptionPassword = try container.decode(String.self, forKey: .vmEncryptionPassword)
        hostName = try container.decodeIfPresent(String.self, forKey: .hostName) ?? ""
        macAddress = try container.decodeIfPresent(String.self, forKey: .macAddress) ?? ""
        windowsUsername = try container.decode(String.self, forKey: .windowsUsername)
        windowsPassword = try container.decodeIfPresent(String.self, forKey: .windowsPassword) ?? ""
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
    
    init() {
        loadConfiguration()
    }
    
    func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            config = decoded
        }
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
