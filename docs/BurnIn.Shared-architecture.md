# BurnIn.Shared Architecture

## Phase 1 boundary

`BurnIn.Shared` contains reusable non-UI code that can be consumed by both the existing burn-in app and the future maintenance app.

`BurnInController` stays in `BurnInApp` in phase 1 because it is burn-in-workflow orchestration and is not used by `BurnInBoardMaintenanceApp`.

## Stays in BurnInApp

- `Program.cs`
- `App.axaml.cs`
- `MainWindow.axaml.cs`
- `BurnInSettingsDialog.axaml.cs`
- `BurnInProfileViewerDlg.axaml.cs`
- `SerialNumberDialog.axaml.cs`
- `BurnInController.cs`
- all `.axaml` files and other Avalonia UI assets

## Move to BurnIn.Shared

### Communication and transport
- `MBC_USB_TCP.cs`
- `MBC_TB.cs`
- `PMBusDev.cs`
- `SMBusDev.cs`

### Device and board abstractions
- `BurnInDev.cs`
- `DCDCConverterBoard.cs`
- `MainBoard.cs`
- `I2CMultiplexerPCA9542A.cs`
- `ADC_ADS1115.cs`
- `ADS1115.cs`
- `AnalogMux.cs`
- `EEPROM_M24C02.cs`
- `TempSensor_TMP1075.cs`

### Shared models, profiles, status, and helpers
- `BurnInAction.cs`
- `BurnInActionEnum.cs`
- `BurnInProfile.cs`
- `BurnInSettings.cs`
- `BurnInStatus.cs`
- `BurnInStatusEnum.cs`
- `MainBoardKind.cs`
- `ProfileStatusEnum.cs`
- `SerialNumberHelper.cs`
- `StatusFile.cs`
- `VDCstatus.cs`
- `VDCStatusEnum.cs`

## Namespace strategy

Use the `BurnIn.Shared` namespace for extracted code. `BurnInApp` references the shared project and imports `BurnIn.Shared` where needed.

## Cross-platform rules

- The shared library must stay Avalonia-free.
- Path handling in shared code must avoid literal `~/...` paths and use resolved .NET paths instead.
- Serial and TCP support stays in the shared library because both future apps need the same hardware substrate.
