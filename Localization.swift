//
//  Localization.swift
//  Coheremote
//
//  国際化（i18n）サポート
//

import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }
}

class LocalizationManager: ObservableObject {
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            loadStrings()
        }
    }
    
    @Published private(set) var strings: [String: String] = [:]
    
    init() {
        let savedLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        self.currentLanguage = AppLanguage(rawValue: savedLang) ?? .english
        loadStrings()
    }
    
    private func loadStrings() {
        // ビルトインの文字列定義
        switch currentLanguage {
        case .english:
            strings = [
                "app_name": "Coheremote",
                "rdp_file": "RDP File",
                "select_rdp": "Select RDP File",
                "icon_image": "Icon Image",
                "select_icon": "Select Icon",
                "vm_path": "VM Path",
                "select_vm": "Select VM",
                "vm_encryption_password": "VM Encryption Password",
                "optional": "(Optional)",
                "windows_username": "Windows Username",
                "suspend_on_exit": "Suspend VM on App Exit",
                "shutdown_on_exit": "Shutdown Windows on App Exit",
                "build": "Build App",
                "language": "Language",
                "licenses": "Licenses",
                "view_licenses": "View Licenses",
                "app_name_prompt": "Application Name",
                "enter_app_name": "Enter the name for your wrapped application",
                "building": "Building...",
                "build_success": "Build Successful",
                "build_error": "Build Error",
                "select_save_location": "Select Save Location",
                "required_field": "This field is required",
                "pyqt6_license": "PyQt6: GNU GPL v3",
                "pyobjc_license": "PyObjC: MIT License",
                "python_license": "Python: PSF License",
                "disk_access_warning": "Important: You must grant Full Disk Access to both Coheremote and all generated apps in System Settings > Privacy & Security > Full Disk Access.",
                "prerequisites": "Prerequisites",
                "prereq_vmware": "VMware Fusion installed in /Applications",
                "prereq_rdp": "Windows App (formerly Microsoft Remote Desktop) installed",
                "prereq_access": "Full Disk Access granted to this app",
                "app_name_label": "Application Name",
                "save_location": "Save Location",
                "save_panel_message": "%@.app will be created in the selected folder",
                "save_panel_message_short": "Select a folder to save the generated app",
                "save_panel_prompt": "Select",
                "required_fields": "Please fill in all required fields",
                "app_subtitle": "Windows app wrapper for macOS",
                "section_output": "Output",
                "section_vm": "Virtual Machine",
                "section_connection": "Connection",
                "close": "Close",
                "menu_language": "Language",
                "overlay_icon": "Add Coheremote badge to icon",
                // Network mode
                "connection_mode": "Connection Mode",
                "mode_local_vm": "Local VM",
                "mode_network": "Network",
                "section_network": "Network",
                "host_name": "Host Name / IP Address",
                "host_name_placeholder": "e.g. 192.168.1.100 or mypc.local",
                "mac_address": "MAC Address",
                "mac_address_placeholder": "e.g. AA:BB:CC:DD:EE:FF",
                "mac_address_hint": "Required for Wake-on-LAN. Leave empty to skip WoL.",
                "prereq_network": "Target machine has RDP enabled and is on the same network",
                "enable_start_menu": "Add App Launcher to menu bar",
                "windows_password": "Windows Password",
                "windows_password_hint": "Required for App Launcher app list. VMware Tools must be installed in the guest.",
                "enable_remote_app": "Convert to RemoteApp",
                "remote_app_hint": "Injects RemoteApp settings into the RDP file. Use when the RDP file was exported from Windows App (full desktop).",
                "remote_app_name": "App Display Name",
                "remote_app_name_placeholder": "e.g. Notepad",
                "remote_app_program": "App Path (Windows)",
                "remote_app_program_placeholder": "e.g. C:\\Windows\\System32\\notepad.exe"
            ]
        case .japanese:
            strings = [
                "app_name": "Coheremote",
                "rdp_file": "RDPファイル",
                "select_rdp": "RDPファイルを選択",
                "icon_image": "アイコン画像",
                "select_icon": "アイコンを選択",
                "vm_path": "VM パス",
                "select_vm": "VMを選択",
                "vm_encryption_password": "VM暗号化パスワード",
                "optional": "（オプション）",
                "windows_username": "Windowsユーザー名",
                "suspend_on_exit": "アプリ終了時にVMをサスペンド",
                "shutdown_on_exit": "アプリ終了時にWindowsをシャットダウン",
                "build": "アプリをビルド",
                "language": "言語",
                "licenses": "ライセンス",
                "view_licenses": "ライセンスを表示",
                "app_name_prompt": "アプリケーション名",
                "enter_app_name": "ラップするアプリケーションの名前を入力してください",
                "building": "ビルド中...",
                "build_success": "ビルド成功",
                "build_error": "ビルドエラー",
                "select_save_location": "保存場所を選択",
                "required_field": "この項目は必須です",
                "pyqt6_license": "PyQt6: GNU GPL v3",
                "pyobjc_license": "PyObjC: MIT ライセンス",
                "python_license": "Python: PSF ライセンス",
                "disk_access_warning": "重要：システム設定 > プライバシーとセキュリティ > フルディスクアクセスで、Coheremoteと生成されたすべてのアプリにフルディスクアクセスを付与する必要があります。",
                "prerequisites": "前提条件",
                "prereq_vmware": "VMware Fusionが/Applicationsにインストールされていること",
                "prereq_rdp": "Windows App（旧Microsoft Remote Desktop）がインストールされていること",
                "prereq_access": "このアプリにフルディスクアクセスが付与されていること",
                "app_name_label": "アプリケーション名",
                "save_location": "保存先",
                "save_panel_message": "選択したフォルダに %@.app が作成されます",
                "save_panel_message_short": "生成されるアプリの保存先フォルダを選択してください",
                "save_panel_prompt": "選択",
                "required_fields": "すべての必須項目を入力してください",
                "app_subtitle": "macOS向けWindowsアプリラッパー",
                "section_output": "出力設定",
                "section_vm": "仮想マシン",
                "section_connection": "接続設定",
                "close": "閉じる",
                "menu_language": "言語",
                "overlay_icon": "Coheremoteバッジをアイコンに追加",
                // ネットワークモード
                "connection_mode": "接続モード",
                "mode_local_vm": "ローカルVM",
                "mode_network": "ネットワーク",
                "section_network": "ネットワーク",
                "host_name": "ホスト名 / IPアドレス",
                "host_name_placeholder": "例: 192.168.1.100 または mypc.local",
                "mac_address": "MACアドレス",
                "mac_address_placeholder": "例: AA:BB:CC:DD:EE:FF",
                "mac_address_hint": "Wake-on-LANに必要です。WoLを使わない場合は空欄にしてください。",
                "prereq_network": "対象マシンでRDPが有効で、同じネットワーク上にあること",
                "enable_start_menu": "メニューバーにアプリランチャーを追加",
                "windows_password": "Windowsパスワード",
                "windows_password_hint": "アプリランチャーのアプリ一覧に必要です。ゲストにVMware Toolsがインストールされている必要があります。",
                "enable_remote_app": "RemoteAppに変換",
                "remote_app_hint": "RDPファイルにRemoteApp設定を注入します。Windows Appからエクスポートしたフルデスクトップ接続のRDPファイルを使用する場合に有効にしてください。",
                "remote_app_name": "アプリ表示名",
                "remote_app_name_placeholder": "例: メモ帳",
                "remote_app_program": "アプリパス（Windows側）",
                "remote_app_program_placeholder": "例: C:\\Windows\\System32\\notepad.exe"
            ]
        }
    }
    
    func string(for key: String) -> String {
        return strings[key] ?? key
    }
}
