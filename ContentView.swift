//
//  ContentView.swift
//  Coheremote
//
//  Created by y-128 on 2026/03/21.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import UserNotifications

struct ContentView: View {
    @ObservedObject var localization: LocalizationManager
    @StateObject private var configManager = ConfigurationManager()

    @State private var showingFileImporter = false
    @State private var fileImporterType: FileImporterType = .rdp
    @State private var showingLicenses = false
    @State private var appName = ""
    @State private var savePath: URL?
    @State private var isBuilding = false
    @State private var buildError: String?
    @State private var showingBuildError = false

    enum FileImporterType {
        case rdp, icon
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                prerequisitesSection

                outputSettingsSection

                vmSettingsSection

                connectionSettingsSection

                buildSection

                licensesSection
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 700)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingLicenses) {
            LicensesView(localization: localization)
        }
        .alert(localization.string(for: "build_error"), isPresented: $showingBuildError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(buildError ?? "Unknown error")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            Image(systemName: "app.connected.to.app.below.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Coheremote")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(localization.string(for: "app_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Prerequisites

    private var prerequisitesSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                prereqRow(icon: "app.badge.checkmark", text: localization.string(for: "prereq_vmware"))
                prereqRow(icon: "rectangle.on.rectangle", text: localization.string(for: "prereq_rdp"))
                prereqRow(icon: "lock.shield", text: localization.string(for: "prereq_access"))

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(localization.string(for: "disk_access_warning"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
            }
            .padding(.top, 8)
        } label: {
            Label(localization.string(for: "prerequisites"), systemImage: "checklist")
                .font(.headline)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func prereqRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Output Settings

    private var outputSettingsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // アプリケーション名
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel(icon: "character.cursor.ibeam", title: localization.string(for: "app_name_label"))
                    TextField(localization.string(for: "enter_app_name"), text: $appName)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                // 保存先
                pathRow(
                    icon: "folder",
                    title: localization.string(for: "save_location"),
                    path: savePath?.path ?? "",
                    buttonTitle: localization.string(for: "select_save_location"),
                    action: { selectSaveLocation() }
                )

                Divider()

                // アイコン画像
                pathRow(
                    icon: "photo",
                    title: localization.string(for: "icon_image"),
                    path: configManager.config.iconImagePath,
                    buttonTitle: localization.string(for: "select_icon"),
                    action: { selectFile(.icon) },
                    optional: true
                )
            }
            .padding(4)
        } label: {
            Label(localization.string(for: "section_output"), systemImage: "shippingbox")
                .font(.headline)
        }
    }

    // MARK: - VM Settings

    private var vmSettingsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // VMパス
                pathRow(
                    icon: "desktopcomputer",
                    title: localization.string(for: "vm_path"),
                    path: configManager.config.vmPath,
                    buttonTitle: localization.string(for: "select_vm"),
                    action: { selectVMFile() }
                )

                Divider()

                // VM暗号化パスワード
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel(
                        icon: "lock",
                        title: localization.string(for: "vm_encryption_password"),
                        optional: true
                    )
                    SecureField("", text: $configManager.config.vmEncryptionPassword)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: configManager.config.vmEncryptionPassword) { _, _ in
                            configManager.saveConfiguration()
                        }
                }

                Divider()

                // トグル
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $configManager.config.closeVMOnExit) {
                        sectionLabel(icon: "pause.circle", title: localization.string(for: "suspend_on_exit"))
                    }
                    .onChange(of: configManager.config.closeVMOnExit) { _, _ in
                        configManager.saveConfiguration()
                    }

                    Toggle(isOn: $configManager.config.shutdownOnExit) {
                        sectionLabel(icon: "power", title: localization.string(for: "shutdown_on_exit"))
                    }
                    .onChange(of: configManager.config.shutdownOnExit) { _, _ in
                        configManager.saveConfiguration()
                    }
                }
            }
            .padding(4)
        } label: {
            Label(localization.string(for: "section_vm"), systemImage: "server.rack")
                .font(.headline)
        }
    }

    // MARK: - Connection Settings

    private var connectionSettingsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // RDPファイル
                pathRow(
                    icon: "doc.badge.gearshape",
                    title: localization.string(for: "rdp_file"),
                    path: configManager.config.rdpFilePath,
                    buttonTitle: localization.string(for: "select_rdp"),
                    action: { selectFile(.rdp) }
                )

                Divider()

                // Windowsユーザー名
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel(icon: "person", title: localization.string(for: "windows_username"))
                    TextField("", text: $configManager.config.windowsUsername)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: configManager.config.windowsUsername) { _, _ in
                            configManager.saveConfiguration()
                        }
                }

            }
            .padding(4)
        } label: {
            Label(localization.string(for: "section_connection"), systemImage: "network")
                .font(.headline)
        }
    }

    // MARK: - Build

    private var buildSection: some View {
        VStack(spacing: 8) {
            Button(action: startBuild) {
                HStack(spacing: 8) {
                    if isBuilding {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "hammer.fill")
                    }
                    Text(isBuilding ? localization.string(for: "building") : localization.string(for: "build"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canBuild || isBuilding)

            if !canBuild && !isBuilding {
                Text(localization.string(for: "required_fields"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Licenses

    private var licensesSection: some View {
        Button(action: { showingLicenses = true }) {
            Label(localization.string(for: "view_licenses"), systemImage: "doc.text")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    // MARK: - Reusable Components

    private func sectionLabel(icon: String, title: String, optional: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.body)
            if optional {
                Text(localization.string(for: "optional"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func pathRow(
        icon: String,
        title: String,
        path: String,
        buttonTitle: String,
        action: @escaping () -> Void,
        optional: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel(icon: icon, title: title, optional: optional)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: path.isEmpty ? "questionmark.folder" : "folder.fill")
                        .foregroundColor(path.isEmpty ? .gray : .blue)
                        .font(.caption)
                    Text(path.isEmpty ? "---" : path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(path.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(path)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var canBuild: Bool {
        !appName.isEmpty && savePath != nil && configManager.isValid()
    }

    // MARK: - Actions

    private func selectSaveLocation() {
        let panel = NSOpenPanel()
        panel.title = localization.string(for: "select_save_location")
        panel.message = localization.string(for: "save_panel_message_short")
        panel.prompt = localization.string(for: "save_panel_prompt")
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.savePath = url
            }
        }
    }

    private func selectFile(_ type: FileImporterType) {
        fileImporterType = type
        showingFileImporter = true
    }

    private func selectVMFile() {
        let panel = NSOpenPanel()
        panel.title = localization.string(for: "select_vm")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false

        let vmDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Virtual Machines.localized")
        if FileManager.default.fileExists(atPath: vmDir.path) {
            panel.directoryURL = vmDir
        }

        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.configManager.config.vmPath = url.path
                self.configManager.saveConfiguration()
            }
        }
    }

    private var allowedContentTypes: [UTType] {
        switch fileImporterType {
        case .rdp:
            return [UTType(filenameExtension: "rdp") ?? .data]
        case .icon:
            return [.png, .jpeg, .image, UTType(filenameExtension: "ico") ?? .data]
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first else { return }

        let path = url.path

        switch fileImporterType {
        case .rdp:
            configManager.config.rdpFilePath = path
        case .icon:
            configManager.config.iconImagePath = path
        }

        configManager.saveConfiguration()
    }

    private func startBuild() {
        guard let saveLocation = savePath else { return }
        performBuild(at: saveLocation)
    }

    private func performBuild(at saveLocation: URL) {
        isBuilding = true
        buildError = nil

        Task {
            do {
                try await AppBuilder.buildApp(
                    appName: appName,
                    config: configManager.config,
                    savePath: saveLocation
                )

                await MainActor.run {
                    isBuilding = false

                    let content = UNMutableNotificationContent()
                    content.title = localization.string(for: "build_success")
                    content.body = "\(appName).app"
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

                    NSWorkspace.shared.selectFile(
                        saveLocation.appendingPathComponent("\(appName).app").path,
                        inFileViewerRootedAtPath: saveLocation.path
                    )
                }
            } catch {
                await MainActor.run {
                    isBuilding = false
                    buildError = error.localizedDescription
                    showingBuildError = true
                }
            }
        }
    }
}

// MARK: - Licenses View

struct LicensesView: View {
    @ObservedObject var localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localization.string(for: "licenses"))
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                LicenseRow(text: localization.string(for: "pyqt6_license"))
                LicenseRow(text: localization.string(for: "pyobjc_license"))
                LicenseRow(text: localization.string(for: "python_license"))
            }

            Spacer()

            HStack {
                Spacer()
                Button(localization.string(for: "close")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380, height: 260)
    }
}

struct LicenseRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
                .font(.callout)
        }
    }
}

#Preview {
    ContentView(localization: LocalizationManager())
}
