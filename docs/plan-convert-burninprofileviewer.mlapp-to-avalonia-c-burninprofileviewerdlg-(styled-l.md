# 🎯 Convert BurnInProfileViewer.mlapp to Avalonia C# BurnInProfileViewerDlg (styled like BurnInSettingsDialog)

## Reference file confirmed
`BurnInApp/BurnInSettingsDialog.axaml` + `.axaml.cs` now exists and defines the exact style conventions to replicate:

- **Window**: `Width`/`Height` fixed, `WindowStartupLocation="CenterOwner"`, `CanResize="False"`, root `<Grid RowDefinitions="*,Auto" Margin="10">`.
- **Labels/fields**: `DockPanel` rows with `Label DockPanel.Dock="Left" Width="280" VerticalAlignment="Center"` + `TextBox` (often `IsReadOnly="True"`) filling remaining space, wrapped in a `StackPanel Margin="10" Spacing="5"` (optionally inside `ScrollViewer`/`TabItem`, but our viewer is simpler — no tabs needed).
- **DataGrid style** (copy verbatim pattern from `IPAddressDataGrid`):
  - `AutoGenerateColumns="False"`, `CanUserReorderColumns="False"`, `CanUserResizeColumns="True"`, `CanUserSortColumns="False"`, `GridLinesVisibility="All"`, `HeadersVisibility="All"`, `BorderBrush="Gray"`, `BorderThickness="1"`, `RowHeight="22"`.
  - `DataGrid.Styles`: `DataGridColumnHeader` → `Background="LightGray"`, `FontWeight="Normal"`, `FontSize="12"`, `Height="22"`, `Padding="5,2"`; `DataGridCell` → `FontSize="12"`, `Padding="5,2"`.
  - Columns as `DataGridTextColumn` with `IsReadOnly="True"` for all (view-only requirement) using `{ReflectionBinding PropName}`.
- **Labels for group headers**: `Label` with `FontSize="12"` for secondary captions (e.g. `IPAddressLabel`).
- **Warning/info TextBlock style**: `FontSize="12"`, `TextWrapping="Wrap"`, `Foreground` color-coded (Orange/Red) — not needed here since view-only, but keep a small info TextBlock if useful (optional, can state "View only").
- **Footer buttons**: `StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Spacing="10"` with `Button Width="90" HorizontalContentAlignment="Center"`. Since this is a viewer only, use a single **Close** button (`IsDefault="True"` and `IsCancel="True"`), no OK/Cancel pair.
- **Code-behind conventions**: `public partial class X : Window`, parameterless ctor calling `InitializeComponent()` (required for Avalonia XAML loader/previewer), a second ctor taking the domain object(s) that also calls `InitializeComponent()` then populates controls via a private `LoadXToControls()`-style method, small private row-model classes (like `IPAddressRow`) defined at the bottom of the same file when needed for `DataGrid.ItemsSource`, `ObservableCollection<T>` for grid-backed collections, `using Avalonia.Controls; Avalonia.Interactivity; System; System.Collections.ObjectModel; System.Linq;` etc.

## MATLAB source recap (Matlab/BurnInProfileViewer.mlapp)
Read-only modal viewer for a `BurnInProfile`:
- `uitable` (`Profile`) — one row per `ProfileStep`: Name, Duration, PowerPerChannel1, MaxCurrent1, MaxVoltage1, Frequency1, DutyCycle1, ComputeVDuT1, [PowerPerChannel2, MaxCurrent2, MaxVoltage2, Frequency2, DutyCycle2, ComputeVDuT2 if nBanks>=2 else "n/a"], Measure. Row header = step index. Currently-running step (`ProfileStatus == RUNNING`, index `CurrProfileStep`) highlighted background orange `#FFCC00`-ish (`[1.0 0.8 0.0]`).
- `FileName` read-only field ← `profile.CompleteFileName`.
- Bank 1 / Bank 2 panels, each read-only: Type (text), Number (numeric, NumberOfChannels[i]), Resistance (numeric, "Ohm" suffix), Deviation (numeric, "Ohm" suffix). Bank 2 panel hidden if `nBanks < 2`.
- `MeasurementRate` read-only field ← `profile.MeasurementRate` (TimeSpan).
- Modal window, all fields `Editable='off'`.

## Target C# model (`BurnInApp/BurnInProfile.cs`)
`BurnInProfile`: `Steps` (List<ProfileStep>), `CompleteFileName`, `Type[]`, `NumberOfChannels[]`, `Resistance[]`, `Deviation[]`, `MeasurementRate` (TimeSpan), `ProfileStatus` (`ProfileStatusEnum`), `CurrProfileStep` (int).
`ProfileStep`: `Name`, `Duration` (TimeSpan), `PowerPerChannel[]`, `MaxCurrent[]`, `MaxVoltage[]`, `Frequency[]`, `DutyCycle[]`, `ComputeVDuT[]` (int[]), `Measure` (double).

## Files & naming
- `BurnInApp/BurnInProfileViewerDlg.axaml`
- `BurnInApp/BurnInProfileViewerDlg.axaml.cs`
- Namespace `BurnInApp`, class `BurnInProfileViewerDlg : Window` (partial), plus private row model class `ProfileStepRow` at bottom of the `.axaml.cs` file (same pattern as `IPAddressRow`).

## Design details
- Constructors:
  - `public BurnInProfileViewerDlg()` → `InitializeComponent()` only (designer/XAML loader support).
  - `public BurnInProfileViewerDlg(BurnInProfile profile, int nBanks)` → `InitializeComponent()`, store fields, call `InitializeProfileGrid()` then `UpdateProfileTable()` (mirrors MATLAB `updateProfileTable`).
- `ProfileStepRow` fields: `StepNumber`, `Name`, `Duration` (string), `PowerPerChannel1`, `MaxCurrent1`, `MaxVoltage1`, `Frequency1`, `DutyCycle1`, `ComputeVDuT1`, `PowerPerChannel2`, `MaxCurrent2`, `MaxVoltage2`, `Frequency2`, `DutyCycle2`, `ComputeVDuT2`, `Measure`, `IsCurrentStep` (bool, for row highlight) — all as `string`/simple types for easy formatted display (mirroring MATLAB `sprintf` formatting), Bank2 columns set to `"n/a"` when `nBanks < 2`.
- `UpdateProfileTable()`: build `ObservableCollection<ProfileStepRow>` from `profile.Steps`, set `ProfileDataGrid.ItemsSource`; set `FileNameTextBox.Text = profile.CompleteFileName`; set Bank 1 fields (`Type1TextBox`, `Number1TextBox`, `Resistance1TextBox`, `Deviation1TextBox`) from index 0; set Bank 2 fields from index 1 and set `Bank2Panel.IsVisible = nBanks >= 2`; set `MeasurementRateTextBox.Text = profile.MeasurementRate.ToString(@"hh\:mm\:ss")` (or similar); mark `IsCurrentStep = true` on the row matching `profile.CurrProfileStep` when `profile.ProfileStatus == ProfileStatusEnum.RUNNING`.
- Row highlighting: use `DataGrid.Styles` with a `Style Selector="DataGridRow"` bound via a `Classes` toggle, or simpler — use a `IValueConverter`/`DataTrigger`-less approach: set `DataGridRow.Background` via `LoadingRow` event handler checking `((ProfileStepRow)e.Row.DataContext).IsCurrentStep` and applying `Avalonia.Media.Brushes.Orange`/`#FFCC00`.
- All DataGrid columns `IsReadOnly="True"`. All TextBoxes `IsReadOnly="True"`. No two-way bindings, no Save/OK button — footer has a single **Close** button (`Click="Close_Click"` → `Close()`), styled `Width="90" HorizontalContentAlignment="Center" IsDefault="True" IsCancel="True"`.
- Window: `Title="Burn-In Profile Viewer"`, reasonable fixed size (e.g. `Width="900" Height="500"`, adjust to fit grid + panels), `WindowStartupLocation="CenterOwner"`, `CanResize="False"`.
- Layout: root `Grid RowDefinitions="Auto,*,Auto" Margin="10"` — row0: FileName DockPanel; row1: DataGrid (Profile steps) with `Height`/`*` sizing; row2: two side-by-side Bank panels (`Grid`/`StackPanel Orientation="Horizontal"`) + MeasurementRate field + Close button row below, OR keep footer row separate as row3 (`Grid RowDefinitions="Auto,*,Auto,Auto"`). Use `Border`+`TextBlock Header` or simple `Label`-titled `StackPanel`s (Avalonia has no native GroupBox) to represent "Bank 1"/"Bank 2" panels, consistent with existing DockPanel/Label pattern in `BurnInSettingsDialog.axaml`.
- XML doc header comment: "Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid".

**Progress**: 100% [██████████]

**Last Updated**: 2026-07-31 14:35:37

## 📝 Plan Steps
- ✅ **Create `BurnInApp/BurnInProfileViewerDlg.axaml`: Window shell (`Width="900" Height="520"`, `CanResize="False"`, `WindowStartupLocation="CenterOwner"`, `Title="Burn-In Profile Viewer"`) with `Grid RowDefinitions="Auto,*,Auto,Auto" Margin="10"`:**
- ✅ **Create `BurnInApp/BurnInProfileViewerDlg.axaml.cs`: `partial class BurnInProfileViewerDlg : Window` with:**
- ✅ **Add XML doc comment header noting MATLAB conversion authorship, consistent with other converted files.**
- ✅ **Cross-check `ProfileStatusEnum` values via `find_symbol`/existing enum file to ensure correct `RUNNING` member name is used.**
- ✅ **Double-check no code path ever writes back into `profile`/`Steps` — purely read/display, fulfilling the "view only, no editing" requirement.**
- ✅ **(Optional/document only) Note intended call site comment: `new BurnInProfileViewerDlg(profile, nBanks).ShowDialog(ownerWindow);` — no forced integration into `BurnInController` unless an obvious call site exists.**

