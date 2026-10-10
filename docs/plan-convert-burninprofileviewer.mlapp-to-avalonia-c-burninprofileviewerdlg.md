# 🎯 Convert BurnInProfileViewer.mlapp to Avalonia C# BurnInProfileViewerDlg

## Context
- Source: `Matlab/BurnInProfileViewer.mlapp` — a MATLAB App Designer modal `uifigure` that displays a **read-only** view of a `BurnInProfile`:
  - A `uitable` (`Profile`) listing all profile steps with columns: Name, Duration, PowerPerChannel1, MaxCurrent1, MaxVoltage1, Frequency1, DutyCycle1, ComputeVDuT1, (if 2 banks) PowerPerChannel2, MaxCurrent2, MaxVoltage2, Frequency2, DutyCycle2, ComputeVDuT2, Measure. Row currently running (`ProfileStatus == RUNNING`) is highlighted (background color `[1.0 0.8 0.0]` / orange) at `currProfileStep`.
  - `FileName` read-only text field bound to `profile.completeFileName`.
  - Two "Bank" `uipanel`s (Bank 1 / Bank 2), each with read-only fields: Type (text), Number (numeric), Resistance (numeric, "Ohm" suffix label), Deviation (numeric, "Ohm" suffix label).
  - `MeasurementRate` read-only text field.
  - `Bank2Panel` is hidden (`Visible = "off"`) when `nBanks < 2`.
  - All input controls have `Editable = 'off'` — **view only, no edit/save capability** must be preserved in C#.
  - Constructed with `(profile, nBanks)` via `runStartupFcn` → `Initialize(app, profile, nBanks)`.

- Target C# model: `BurnInApp/BurnInProfile.cs` already has matching properties: `ProfileStep` (Name, Duration, PowerPerChannel[], MaxCurrent[], MaxVoltage[], Frequency[], DutyCycle[], ComputeVDuT[], Measure), `BurnInProfile` (Steps, CompleteFileName, Type[], NumberOfChannels[], Resistance[], Deviation[], MeasurementRate, ProfileStatus, CurrProfileStep).

- Project uses **Avalonia UI** (`Program.cs` → `AppBuilder.Configure<App>()`), .NET 10. No `.axaml` files currently exist anywhere in the checked-out workspace, and no `BurnInSettingsDialog.axaml.cs` file is present despite the user referencing it from an earlier session — **it could not be located for direct copying**. Proceeding with idiomatic Avalonia code-behind conventions consistent with this project's plain, non-MVVM C# style (as seen in `BurnInSettings.cs`, `BurnInProfile.cs`), keeping XAML markup for layout and doing data population/logic in code-behind — mirroring how the executing agent should structure `BurnInSettingsDialog` if/when it reappears. If an actual `BurnInSettingsDialog.axaml`/`.axaml.cs` surfaces in the working tree before implementation, its exact conventions (namespaces, base class usage, DataGrid style, close-button pattern, window sizing) should take precedence over assumptions below.

## Naming & Location
- New files: `BurnInApp/BurnInProfileViewerDlg.axaml` and `BurnInApp/BurnInProfileViewerDlg.axaml.cs`, in the `BurnInApp` project root (same folder as `BurnInSettings.cs`, `BurnInProfile.cs`).
- Namespace: `BurnInApp`.
- Class name: `BurnInProfileViewerDlg`, inherits `Avalonia.Controls.Window`.

## Design
- Constructor: `public BurnInProfileViewerDlg(BurnInProfile profile, int nBanks)` — stores profile/nBanks, populates all UI fields, hides Bank 2 panel when `nBanks < 2`.
- Also keep a parameterless constructor for the Avalonia XAML loader (`InitializeComponent()`), per typical Avalonia Window pattern.
- Invocation pattern: modal via `ShowDialog(Window owner)` — e.g. static helper `public static Task ShowDialogAsync(Window owner, BurnInProfile profile, int nBanks)` or simply instantiate & call `.ShowDialog(owner)` from caller (BurnInController/UI layer). Keep it simple: just the Window class; caller does `new BurnInProfileViewerDlg(profile, nBanks).ShowDialog(owner)`.
- UI Controls (all read-only — `IsReadOnly="True"` / `IsEnabled` where appropriate, but since it's purely a viewer, prefer read-only TextBox/NumericUpDown or plain TextBlocks):
  - `DataGrid` (Avalonia.Controls.DataGrid, `IsReadOnly="True"`, `CanUserSortColumns="False"`) bound to a list of row view-model objects built from `profile.Steps` (one row per step, columns matching MATLAB table: Name, Duration, PowerPerChannel1, MaxCurrent1, MaxVoltage1, Frequency1, DutyCycle1, ComputeVDuT1, [Bank2 columns if nBanks>=2], Measure).
  - Highlight current running step row (when `profile.ProfileStatus == ProfileStatusEnum.RUNNING`) with an orange background — implement via DataGrid row style/converter or manual styling on load (e.g., `LoadingRow` event checking row index against `profile.CurrProfileStep`).
  - `FileName` read-only TextBox bound to `profile.CompleteFileName`.
  - Bank 1 panel: Type1, Number1 (NumberOfChannels[0]), Resistance1, Deviation1 — read-only TextBoxes with "Ohm" labels for Resistance/Deviation.
  - Bank 2 panel: same fields from index [1]; entire panel `IsVisible = nBanks >= 2`.
  - MeasurementRate read-only TextBox bound to `profile.MeasurementRate` (format as string, e.g. `"hh\\:mm\\:ss"` or similar TimeSpan format).
  - Window title e.g. "Burn-In Profile Viewer", non-resizable or reasonably sized, `WindowStartupLocation="CenterOwner"`.
- No Save/Apply/Cancel buttons with mutation semantics — only a "Close" button (or rely on window close button). No two-way bindings that write back to `BurnInProfile`.
- Follow the file's own established comment convention seen elsewhere in the codebase: header doc-comment stating "Converted from MATLAB class ... by Torsten Blochwitz Electronics & Software for InfraSolid".

## Risks / Open Items
- `BurnInSettingsDialog.axaml.cs` referenced by the user is not present in the workspace; exact structural conventions (DataGrid styling, button placement, code-behind organization) are inferred rather than copied. Flag this to the user once implementation begins and adjust if the actual file becomes available (e.g., pulled from another branch/stash).
- Need to confirm ProfileStep duration formatting (MATLAB uses `duration` string like `hh:mm:ss`); use `TimeSpan.ToString()` with an appropriate format string for parity.

**Last Updated**: 2026-07-31 14:27:16

## 📝 Plan Steps
-  **Create `BurnInApp/BurnInProfileViewerDlg.axaml` — define an Avalonia `Window` with a `DataGrid` for profile steps, `FileName` field, Bank 1 / Bank 2 `Panel`/`GroupBox`-style sections (Type, Number, Resistance, Deviation with "Ohm" labels), a `MeasurementRate` field, and a Close button. All data-entry controls read-only.**
-  **Create `BurnInApp/BurnInProfileViewerDlg.axaml.cs` — code-behind class `BurnInProfileViewerDlg : Window` with parameterless constructor (calls `InitializeComponent()`), and `(BurnInProfile profile, int nBanks)` constructor that stores fields and calls a `PopulateData()`/`UpdateProfileTable()` method mirroring MATLAB's `updateProfileTable`.**
-  **Implement `UpdateProfileTable()` — build a list of row objects from `profile.Steps` (including Bank 2 columns only if `nBanks >= 2`, else "n/a"), bind to the DataGrid's `ItemsSource`, set `FileName`, Bank 1/2 Type/Number/Resistance/Deviation fields, `MeasurementRate` text, hide `Bank2Panel` when `nBanks < 2`, and highlight the currently running step's row when `profile.ProfileStatus == ProfileStatusEnum.RUNNING` using `profile.CurrProfileStep`.**
-  **Add XML doc-comments matching project convention: "Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid".**
-  **Verify the class compiles against the existing `BurnInProfile`, `ProfileStep`, and `ProfileStatusEnum` types (check `ProfileStatusEnum` values via `find_symbol` if needed) and that no property is ever set back onto `profile` (view-only guarantee).**
-  **Optionally wire up a caller (not required unless a natural call site like `BurnInController` UI exists) — leave a TODO/comment on how to invoke: `new BurnInProfileViewerDlg(profile, nBanks).ShowDialog(ownerWindow)`.**

