# 🎯 Transform MainWindow from MATLAB BurnInApp

Replace the placeholder `MainWindow` with a controller-backed eight-board Avalonia UI. Preserve and wire the existing quick `Connect MBC`, `Settings...`, and data-table controls. Exclude all Keithley/DMM functionality.

The window will own `BurnInController` instead of a separate placeholder settings object and will run its non-DMM action loop every 500 ms. The existing data table will contain persistent rows for the eight boards and display profile, serial-number range, start/end times, current action, status, and VDC values.

The UI will add per-row `Load...`, `Start`/`Stop`/`Continue`, and `Reset` controls; a `Start all` action; profile loading; serial-number editing through `SerialNumberDialog`; controller-driven display refresh; and safe shutdown handling. No activity lamp, table-visibility checkbox, automatic hiding, DMM controls, DMM connection, DMM status, or profile viewer will be ported.

Maintain Windows/Linux compatibility with Avalonia `StorageProvider` file selection, `DispatcherTimer`, platform-neutral path APIs, and owner-relative Avalonia dialogs. Do not introduce registry, WinForms, WPF, or other Windows-only APIs.

**Progress**: 100% [██████████]

**Last Updated**: 2026-08-15 12:36:50

## 📝 Plan Steps
- ✅ **Replace `BurnInApp/MainWindow.axaml` — retain the MBC connection/status controls and existing data table; add a `Start all` action and per-board `Load...`, `Start`, and `Reset` controls; omit DMM, activity-lamp, table-visibility, and auto-hide controls.**
- ✅ **Rewrite `BurnInApp/MainWindow.axaml.cs` — create and own `BurnInController`; replace sample rows with observable board rows; implement MBC connection, cross-platform profile file selection/loading through Avalonia `StorageProvider`, serial-number editing, start/stop/continue/reset actions, and settings refresh.**
- ✅ **Implement the periodic controller loop and UI refresh in `MainWindow` — use Avalonia `DispatcherTimer` to safely invoke `DoAction()`, update all board status and VDC display fields, calculate serial-number ranges, and synchronize command enablement/text with controller state.**
- ✅ **Add cross-platform shutdown handling in `MainWindow` — stop the dispatcher timer, show an owner-relative Avalonia confirmation dialog, and call `SwitchOffEverything()` only when confirmed.**
- ✅ **Build the .NET 10 solution — resolve Avalonia XAML/code-behind issues and verify all non-DMM MainWindow workflows compile without platform-specific dependencies.**

