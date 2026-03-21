# Coheremote

Coheremote is a macOS application that generates native wrapper apps for Windows applications running in VMware Fusion VMs. Using RemoteApp (RDP) technology, it integrates Windows apps into the macOS Dock as if they were native applications.

## Features

- **Native Compiled Wrappers**: Generated apps are compiled Swift binaries, not shell scripts
- **Status Window**: Displays real-time status (starting VM, connecting, suspending...) during operations
- **Dock Menu**: Right-click the wrapper's Dock icon to restart Windows
- **Persistent Wrapper**: The wrapper app stays running after launching Windows App, enabling VM lifecycle management
- **Auto VM Suspend**: Automatically suspends the VM when the wrapper app quits (configurable)
- **Smart VM Startup**: Detects VM state instantly; connects immediately if already running
- **Encrypted VM Support**: Handles encrypted VMs with password stored securely in macOS Keychain
- **Auto-Login**: Username injection into RDP files for streamlined authentication
- **Custom Icons**: Supports PNG, JPG, ICO, and ICNS formats for app icons
- **Multi-language UI**: English and Japanese
- **Configuration Persistence**: Settings are saved automatically for quick regeneration

## Prerequisites

- **macOS 13.0** (Ventura) or later
- **VMware Fusion**: Installed in `/Applications/VMware Fusion.app`
- **Windows App** (or Microsoft Remote Desktop): Installed from the Mac App Store
- **RemoteApp Tool**: Required to create RemoteApp `.rdp` files on the Windows side - [RemoteApp Tool (GitHub)](https://github.com/kimmknight/remoteapptool)
- **Xcode Command Line Tools**: `swiftc` is required for compiling generated apps
- **Full Disk Access**: You **must** grant Full Disk Access to:
  - Coheremote.app itself
  - Every generated wrapper app

### Granting Full Disk Access

1. Open **System Settings** > **Privacy & Security** > **Full Disk Access**
2. Click **+** and add **Coheremote.app**
3. After building wrapper apps, add each generated `.app` as well

Without Full Disk Access, `vmrun` cannot control VMware Fusion.

## Installation

1. Download Coheremote
2. Move to `/Applications`
3. Grant Full Disk Access (see above)
4. Launch Coheremote

## Usage

### Creating a Wrapper App

1. **Launch Coheremote**

2. **Configure**:
   - **Application Name**: Name for the generated wrapper app
   - **Save Location**: Where to save the generated `.app`
   - **Icon Image** (optional): PNG, JPG, ICO, or ICNS file
   - **VM Path**: `.vmx` file or `.vmwarevm` bundle
   - **VM Encryption Password** (optional): For encrypted VMs
   - **RDP File**: Your RemoteApp `.rdp` file
   - **Windows Username**: For auto-login

3. **Options**:
   - **Suspend VM on App Exit** (default: ON): Suspends the VM when you quit the wrapper app
   - **Shutdown Windows on App Exit** (default: OFF): Shuts down Windows when you quit (takes priority over suspend)

4. Click **Build App**

5. **Grant Full Disk Access** to the newly generated app

### Using a Generated Wrapper App

1. **Launch**: Double-click the generated `.app`
2. A status window appears showing the current operation:
   - *Launching VMware Fusion...* (if not running)
   - *Starting VM...* / *Resuming VM...*
   - *Waiting for VM...*
   - *Connecting...*
3. Once connected, the status window hides automatically
4. The wrapper stays in the Dock for ongoing VM management

### Dock Menu (Right-Click)

Right-click the wrapper's Dock icon to access:

| Menu | Description |
|------|-------------|
| **Reconnect** | Re-establish the RDP connection (use when you've closed the Windows app) |
| **Restart Windows** | Sends a soft restart to the VM, then reconnects RDP automatically |
| **Shutdown and Quit** | Shuts down Windows and then quits the wrapper app |

### Quitting

**Cmd+Q** or right-click Dock > **Quit** performs the following based on settings:

| Setting | Behavior on Quit |
|---------|-----------------|
| Suspend ON / Shutdown OFF | Suspends the VM and quits |
| Shutdown ON | Shuts down Windows and quits (takes priority over suspend) |
| Both OFF | Quits immediately (VM stays running) |

## How It Works

### Generator (Coheremote)

Coheremote builds standalone `.app` bundles by:

1. Modifying the RDP file to inject the Windows username
2. Converting custom icons to macOS `.icns` format (with Retina support)
3. Storing the VM encryption password in macOS Keychain
4. Compiling a native Swift binary from a template using `swiftc`
5. Packaging everything into a standard `.app` bundle

### Generated App Structure

```
MyApp.app/
  Contents/
    Info.plist
    MacOS/
      MyApp          # Compiled Swift binary
    Resources/
      AppIcon.icns   # App icon
      app.rdp        # Modified RDP file
```

### Generated App Behavior

Each compiled wrapper app:

1. **Launches VMware Fusion** if not already running
2. **Starts/resumes the VM** using `vmrun`, with fallback to `open -a "VMware Fusion"` for encrypted VMs
3. **Polls VM status** every second until it's running (timeout: 120s)
4. **Opens the RDP connection** via Windows App (or Microsoft Remote Desktop)
5. **Stays running** in the Dock for VM lifecycle management
6. **Suspends the VM** on quit (if configured)
7. **Logs** all operations to `~/Library/Logs/Coheremote/`

## Troubleshooting

### "Operation not permitted" errors

Full Disk Access has not been granted. Add the app to System Settings > Privacy & Security > Full Disk Access.

### VM doesn't start

- Verify VMware Fusion is installed in `/Applications`
- Check the VM path is correct
- For encrypted VMs, ensure the password is correct
- The wrapper tries `vmrun start` first, then falls back to launching VMware Fusion directly. Check the log file for details.

### RemoteApp shows only IME (no application window)

This is a Windows-side issue, not a Coheremote problem. To fix:

1. **Restart Windows** via Dock menu (right-click > Restart Windows) or manually restart the VM
2. If the issue persists, on the Windows side:
   - Open Registry Editor and navigate to `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList`
   - Verify your RemoteApp entries are correct
   - Restart the Remote Desktop Services (`TermService`)
3. Re-export the `.rdp` file from Windows and rebuild the wrapper app

### Auto-login doesn't work

- On the **first** connection, Windows App may prompt to save credentials to Keychain
- Click "Allow" / "Continue" to enable automatic login on subsequent launches
- If the prompt doesn't appear, try deleting the existing Keychain entry for this RDP connection and reconnecting

### Closed the Windows app by mistake

Select **Reconnect** from the Dock menu (right-click) to re-establish the RDP connection.

### Using multiple Windows apps simultaneously

When launching two or more wrapper apps at the same time, the second app's window may not appear. If this happens, right-click the app's Dock icon and select **Reconnect**.

**Note**: If multiple wrapper apps share the same VM, quitting one of them will suspend or shut down the VM, affecting the other apps as well. This issue is planned to be addressed in a future update.

### RDP connection fails

- Verify Windows App (or Microsoft Remote Desktop) is installed
- Check the RDP file is valid (try opening it manually)
- Ensure Windows credentials are correct

### Windows hangs or freezes

Use the wrapper's Dock menu:
1. Right-click the wrapper icon in the Dock
2. Select **Restart Windows**
3. The VM receives a soft reset, and the wrapper automatically reconnects when Windows comes back up

### Checking log files

Each wrapper app logs to `~/Library/Logs/Coheremote/<AppName>.log`. Open this file to see detailed startup, connection, and error information:

```bash
cat ~/Library/Logs/Coheremote/<AppName>.log
```

Logs are automatically rotated when they exceed 1 MB.

## Building from Source

Coheremote is a SwiftUI macOS project. To build:

1. Open the project in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (Cmd+R)

### Source Files

| File | Description |
|------|-------------|
| `CoheremoteApp.swift` | App entry point, language menu |
| `ContentView.swift` | Main UI |
| `Localization.swift` | i18n support (English/Japanese) |
| `VMwareManager.swift` | VM control via `vmrun` |
| `RDPManager.swift` | RDP file modification (BOM-preserving) |
| `AppConfiguration.swift` | Settings persistence |
| `AppBuilder.swift` | Wrapper app generation and compilation |
| `WrapperTemplate.txt` | Swift source template for generated binaries |

## License

MIT License. See [LICENSE](LICENSE) for details.

### Important Notes

- Generated wrapper apps are for **personal use**
- Ensure compliance with Microsoft and VMware licensing terms
- Windows passwords are not stored by Coheremote; they are managed by Windows App via macOS Keychain on first connection

## Credits

Created by y-128 in 2026.
