# BurnIn suite installation and packaging

This repository contains two desktop apps that are now packaged together as one suite:

- `BurnInApp`
- `BurnInBoardMaintenanceApp` (`BurnInMaintenanceApp` in this document's user-facing wording)

## 1. Build configurations

A shared solution-wide Linux x86 configuration is available:

- `LinuxDebug | x86`
- `LinuxRelease | x86`

You can use it in Visual Studio or on the command line:

- Visual Studio: select `LinuxRelease` and `x86` in the solution configuration drop-downs.
- CLI build: `dotnet build .\BurnInApp.slnx -c LinuxRelease -p:Platform=x86`

Note: `.NET 10` does not provide a native app host for `linux-x86`, so Linux x86 outputs are framework-dependent and start with `dotnet <app>.dll`.

## 2. Packaging outputs added in this repository

Two packaging flows are prepared:

- Windows: one bundled **MSIX** containing both applications
- Linux: one bundled **tar.gz** containing both applications

Packaging files are stored here:

- Windows MSIX: `packaging/windows/`
- Linux tar.gz: `packaging/linux/`

## 3. Prerequisites

### For building packages

Install:

1. .NET 10 SDK
2. For Windows MSIX packaging:
   - Windows SDK with `makeappx.exe` and `signtool.exe`
   - a code-signing certificate, or use the included test-certificate helper
3. For Linux tar.gz packaging on Windows:
   - Windows `tar.exe` support

### For Windows target machines

Install:

1. The required hardware drivers for your USB/serial devices
2. If you use the Keithley/DMM connection configured by `DMM6500_ID`, install the matching instrument driver/runtime used in your environment
3. If you distribute a test-signed MSIX, install the matching certificate into the target machine's trusted certificate store before installation

Note: the Windows MSIX packaging script publishes self-contained `win-x64` outputs by default, so a separate .NET runtime is normally not required on the target machine.

### For Linux x86 target machines

Install:

1. The .NET 10 runtime for Linux x86
2. The native desktop libraries required by Avalonia on your distribution
   - On Debian/Ubuntu systems this is typically packages such as `libfontconfig1`, `libfreetype6`, `libx11-6`, `libxext6`, and `libxrender1`
3. Access to the serial device used by the MBC
   - Usually this means adding the user to the `dialout` group
   - Example: `sudo usermod -aG dialout <user>`
4. If you use the Keithley/DMM connection configured by `DMM6500_ID`, install the matching instrument driver/runtime used in your environment

## 4. Create the Windows MSIX package

Run all commands from the repository root.

### Option A: create a bundled MSIX with a temporary test certificate

`powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows\Create-BurnInSuiteMsix.ps1 -CreateTestCertificate -CertificatePassword "YourStrongPassword123!"`

This will:

1. Publish `BurnInApp` for `win-x64`
2. Publish `BurnInBoardMaintenanceApp` for `win-x64`
3. Stage both apps into one MSIX layout
4. Generate placeholder tile/logo assets for the package
5. Create a test certificate and sign the package

### Option B: create a bundled MSIX with an existing certificate

`powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows\Create-BurnInSuiteMsix.ps1 -CertificatePath "C:\Certificates\BurnInSuite.pfx" -CertificatePassword "YourPfxPassword"`

### Optional: create only the test certificate first

`powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows\New-BurnInSuiteTestCertificate.ps1`

### Windows output location

The bundled package is created here:

- `artifacts\packages\windows\package\BurnInSuite-<version>-win-x64.msix`

If you use `-CreateTestCertificate`, the generated `.pfx` file is stored beside the package.

## 5. Install the bundled MSIX on Windows

1. Copy the generated `.msix` file to the target machine.
2. If the package is test-signed, also copy the generated `.pfx` certificate.
3. Import the certificate into `Trusted People` for the current user or local machine.
4. Double-click the `.msix` file and complete the install dialog.
5. After installation, open the Start menu.
6. You should see both apps:
   - `BurnIn App`
   - `BurnIn Maintenance App`
7. Start each app once and confirm that settings/data folders are created.

## 6. Create the bundled Linux tar.gz package

Run:

`powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\linux\Create-BurnInSuiteTarGz.ps1`

This will:

1. Publish `BurnInApp` for `LinuxRelease | x86`
2. Publish `BurnInBoardMaintenanceApp` for `LinuxRelease | x86`
3. Place both apps into one bundle folder
4. Add launcher scripts for both apps
5. Create one `.tar.gz` archive

### Linux output location

The bundled archive is created here:

- `artifacts\packages\linux\BurnInSuite-<version>-linux-x86.tar.gz`

## 7. Install the bundled tar.gz on Linux x86

1. Copy the generated `.tar.gz` file to the Linux target machine.
2. Extract it, for example:
   - `tar -xzf BurnInSuite-3.2.2-linux-x86.tar.gz`
3. Enter the extracted folder:
   - `cd BurnInSuite`
4. For a quick start without installation:
   - `chmod +x start-burninapp.sh start-burninmaintenanceapp.sh`
   - `./start-burninapp.sh`
   - `./start-burninmaintenanceapp.sh`
5. For a simple folder installation:
   - `chmod +x install.sh`
   - `sudo ./install.sh`
6. The default install folder is `/opt/BurnInSuite`.
7. After installation, start the apps with:
   - `/opt/BurnInSuite/start-burninapp.sh`
   - `/opt/BurnInSuite/start-burninmaintenanceapp.sh`

## 8. Config and data locations created by the apps

### BurnInApp

Windows:

- Config folder: `%LOCALAPPDATA%\BurnInApp`
- Settings file: `%LOCALAPPDATA%\BurnInApp\BurnInSettings.json`
- Default data folder: `%LOCALAPPDATA%\BurnInApp\Measurements`
- Status folder: `%LOCALAPPDATA%\BurnInApp\Status`
- Profiles folder: `%LOCALAPPDATA%\BurnInApp\Profiles`

Linux:

- Config folder: `~/.config/BurnInApp`
- Settings file: `~/.config/BurnInApp/BurnInSettings.json`
- Default data folder: `~/.local/share/BurnInApp/Measurements`
- Status folder: `~/.local/share/BurnInApp/Status`
- Profiles folder: `~/.local/share/BurnInApp/Profiles`

### BurnInBoardMaintenanceApp

Windows:

- Config folder: `%LOCALAPPDATA%\BurnInBoardMaintenanceApp`
- Settings file: `%LOCALAPPDATA%\BurnInBoardMaintenanceApp\BurnInBoardMaintenanceSettings.json`
- Default data folder: `%LOCALAPPDATA%\BurnInBoardMaintenanceApp\Measurements`

Linux:

- Config folder: `~/.config/BurnInBoardMaintenanceApp`
- Settings file: `~/.config/BurnInBoardMaintenanceApp/BurnInBoardMaintenanceSettings.json`
- Default data folder: `~/.local/share/BurnInBoardMaintenanceApp/Measurements`

## 9. Serial-port notes for Linux

The code uses `/dev/ttyUSB-MBC` as the default Linux serial-port name when the MBC is used in I2C mode.

You have two options:

1. Enter the real device path in the app settings, for example `/dev/ttyUSB0`.
2. Create a persistent udev rule or symlink so the device is available as `/dev/ttyUSB-MBC`.

Also make sure the user account that starts the app has permission to open the serial device.

## 10. Quick verification after installation

For both apps on both operating systems:

1. Start the app.
2. Open the communication/settings UI.
3. Verify the MBC connection settings.
4. Verify that the measurements folder is writable.
5. Connect the hardware and perform a basic communication test.
