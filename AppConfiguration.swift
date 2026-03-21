//
//  AppConfiguration.swift
//  Coheremote
//
//  アプリ設定の保存と読み込み
//

import Foundation
import Combine

struct AppConfiguration: Codable {
    var rdpFilePath: String
    var iconImagePath: String
    var vmPath: String
    var vmEncryptionPassword: String
    var windowsUsername: String
    var closeVMOnExit: Bool
    var shutdownOnExit: Bool

    init() {
        self.rdpFilePath = ""
        self.iconImagePath = ""
        self.vmPath = ""
        self.vmEncryptionPassword = ""
        self.windowsUsername = ""
        self.closeVMOnExit = true
        self.shutdownOnExit = false
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
        return !config.rdpFilePath.isEmpty &&
               !config.vmPath.isEmpty &&
               !config.windowsUsername.isEmpty
    }
}
