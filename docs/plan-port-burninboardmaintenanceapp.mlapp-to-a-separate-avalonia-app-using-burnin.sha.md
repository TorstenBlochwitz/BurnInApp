# 🎯 Port `BurnInBoardMaintenanceApp.mlapp` to a Separate Avalonia App Using `BurnIn.Shared`

I explored the current C# solution and the MATLAB sources relevant to this port. The solution now has the right reusable substrate in `BurnIn.Shared`, including hardware and support types such as `BurnInDev`, `MBC_TB`, `BurnInSettings`, board/device classes, and related communication logic. The existing Avalonia app (`BurnInApp`) uses a pragmatic code-behind approach with the Fluent theme and Inter font (`BurnInApp/App.axaml`, `BurnInApp/MainWindow.axaml`), which matches the requested direction for the maintenance app.

The MATLAB `BurnInBoardMaintenanceApp.mlapp` is a large single-window tool with three main functional sections plus a status area:
- `ConnectPanel` for MBC/DMM/board connection and UUID operations (`Matlab/BurnInBoardMaintenanceApp.mlapp:1641-1819`)
- `DCDCConverterPanel` for voltage, frequency, duty cycle, status, timer, ATtiny, and RGB LED operations (`Matlab/BurnInBoardMaintenanceApp.mlapp:1084-1412`)
- `MainBoardPanel` for mux, single measurement, temperature, folder/postfix, timer/skip, and measurement-launch actions (`Matlab/BurnInBoardMaintenanceApp.mlapp:1413-1640`)
- `LabelStatus` as the multiline status output (`Matlab/BurnInBoardMaintenanceApp.mlapp:1815-1820`)

The app depends on two other MATLAB apps that are explicitly out of scope for now:
- `BurnInBoardMaintenanceMeasApp` is opened from `MeasurementButtonPushed` (`Matlab/BurnInBoardMaintenanceApp.mlapp:890-893`)
- `CommunicationSettingsDlg` is opened from `CommunicationSettingsButtonPushed` (`Matlab/BurnInBoardMaintenanceApp.mlapp:1066-1069`)

For this first C# port, those dependencies should be represented by dummy Avalonia dialogs so the main app remains runnable and the later detailed ports can plug in cleanly.

A key UI decision is the replacement of MATLAB `DiscreteKnob` controls. In the MATLAB app, `SwitchVDC1`, `SwitchVDC2`, and `SwitchDCDCConStatusLED` are all three-state controls with the values `Off`, `On`, and `Blink` (`Matlab/BurnInBoardMaintenanceApp.mlapp:1089-1105`, `1221-1228`). The best fit in the current Avalonia style is a horizontal `RadioButton` group for each control rather than a custom knob. This keeps all states visible, avoids custom control work, and is clearer on desktop than a knob metaphor. A `ComboBox` is the fallback only if the layout becomes too dense.

Recommended repository/project shape:
- keep `BurnInApp` unchanged as the burn-in app
- add a separate executable project `BurnInBoardMaintenanceApp` beside it in the same solution
- reference `BurnIn.Shared` from the new project
- keep the new app Avalonia-first and code-behind-driven, matching the existing app style

Recommended architecture for the first maintenance-app port:
- create a small app-specific orchestration class such as `BoardMaintenanceController` inside the new project
- let `MainWindow.axaml.cs` remain pragmatic, but avoid placing all hardware workflow directly into the window code
- reuse `BurnIn.Shared` types directly for hardware communication and device behavior
- defer deeper MVVM or service layering until after feature parity is reached

Recommended first-scope features to port from `BurnInBoardMaintenanceApp.mlapp`:
- app startup, title/version, and settings initialization
- MBC connect, DMM connect, and board connect flows
- status lamp equivalents and status text updates
- DCDC board UUID get/set and software-version display
- Main board UUID get/set
- VDC1/VDC2 voltage spinners and frequency/duty controls
- `Off`/`On`/`Blink` switching for VDC1, VDC2, and DCDC status LED
- DCDC timer get/set and ATtiny status get/set
- DCDC status table display
- MUX selection and single measurement UI
- temperature reads and main-board status LED toggle
- folder/postfix and periodic measurement controls
- placeholder launch points for the two not-yet-ported dialogs

Features to defer in this phase:
- real implementation of `BurnInBoardMaintenanceMeasApp`
- real implementation of `CommunicationSettingsDlg`
- hidden/disabled `Test...` long-term test workflow, since it is already hidden and disabled in MATLAB (`Matlab/BurnInBoardMaintenanceApp.mlapp:1798-1805`)
- broader architectural cleanup beyond what is needed for a stable first port

Expected new files in the first implementation:
- `BurnInBoardMaintenanceApp/BurnInBoardMaintenanceApp.csproj`
- `BurnInBoardMaintenanceApp/Program.cs`
- `BurnInBoardMaintenanceApp/App.axaml`
- `BurnInBoardMaintenanceApp/App.axaml.cs`
- `BurnInBoardMaintenanceApp/MainWindow.axaml`
- `BurnInBoardMaintenanceApp/MainWindow.axaml.cs`
- `BurnInBoardMaintenanceApp/BoardMaintenanceController.cs`
- `BurnInBoardMaintenanceApp/BurnInBoardMaintenanceMeasDialog.axaml`
- `BurnInBoardMaintenanceApp/BurnInBoardMaintenanceMeasDialog.axaml.cs`
- `BurnInBoardMaintenanceApp/CommunicationSettingsDialog.axaml`
- `BurnInBoardMaintenanceApp/CommunicationSettingsDialog.axaml.cs`
- small helper types for table rows and UI state if needed

Main risks and constraints:
- the MATLAB app mixes UI code and hardware actions heavily, so callback-by-callback transfer is safer than redesigning the flow first
- timer-based and long-running hardware operations will require careful Avalonia UI-thread coordination
- some maintenance-app settings may need their own identity rather than reusing `BurnInApp` defaults blindly
- because the two dependent dialogs are missing for now, their button paths must be stubbed clearly rather than partially implemented

**Progress**: 100% [██████████]

**Last Updated**: 2026-10-10 15:34:15

## 📝 Plan Steps
- ✅ **Add `BurnInBoardMaintenanceApp` — create a separate `net10.0` Avalonia executable project beside `BurnInApp`, add it to `BurnInApp.slnx`, and reference `BurnIn.Shared`.**
- ✅ **Reuse app styling — copy the Fluent theme, font setup, and general layout conventions from `BurnInApp` so the new app has the same visual style from the start.**
- ✅ **Add maintenance orchestration — create `BoardMaintenanceController` in the new app project to own settings, connection state, hardware references, and status aggregation without moving that logic into `BurnIn.Shared`.**
- ✅ **Build the main window shell — create `MainWindow.axaml` and `MainWindow.axaml.cs` for the new app, organized around `Connect`, `DC/DC Converter`, `Main Board`, and status sections matching the MATLAB layout.**
- ✅ **Port connection features — implement MBC connect, DMM connect, board connect, status indicator updates, UUID get/set actions, and software-version display using `BurnIn.Shared` types.**
- ✅ **Replace discrete knobs — implement the MATLAB three-state `DiscreteKnob` controls as horizontal `RadioButton` groups for `Off`, `On`, and `Blink` for VDC1, VDC2, and the DCDC status LED.**
- ✅ **Port DC/DC operations — add VDC, frequency, duty cycle, timer, ATtiny status, RGB LED, and status-table behavior from the MATLAB `DCDCConverterPanel`.**
- ✅ **Port main-board operations — add mux selection, single measurement, temperature reading, status LED toggle, folder/postfix controls, and periodic-measurement UI behavior from the MATLAB `MainBoardPanel`.**
- ✅ **Stub dependent dialogs — add dummy Avalonia dialogs for `BurnInBoardMaintenanceMeasApp` and `CommunicationSettingsDlg`, wire their launch buttons, and clearly mark them as placeholders for later implementation.**
- ✅ **Defer hidden test flow — leave the hidden/disabled `Test...` workflow unimplemented in the first port unless a later step makes it necessary.**

