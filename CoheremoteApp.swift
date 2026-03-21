//
//  CoheremoteApp.swift
//  Coheremote
//
//  Created by y-128 on 2026/03/21.
//

import SwiftUI

@main
struct CoheremoteApp: App {
    @StateObject private var localization = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            ContentView(localization: localization)
        }
        .windowResizability(.contentSize)
        .commands {
            // 「設定」メニューの後にカスタムメニューを追加
            CommandMenu(localization.string(for: "menu_language")) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        localization.currentLanguage = language
                    } label: {
                        if localization.currentLanguage == language {
                            Text("\(language.displayName)")
                        } else {
                            Text(language.displayName)
                        }
                    }
                    .keyboardShortcut(language == .english ? "e" : "j",
                                      modifiers: [.command, .shift])
                }
            }
        }
    }
}
