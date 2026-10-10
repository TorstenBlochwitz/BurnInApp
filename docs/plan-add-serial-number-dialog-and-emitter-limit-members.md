# 🎯 Add Serial Number Dialog and Emitter-Limit Members

Implement the MATLAB `SerialNumberDlg` as an Avalonia modal dialog, following the existing `BurnInSettingsDialog` XAML/code-behind convention. Per the selected scope, this will not modify `MainWindow` or add a launcher; callers will instantiate the dialog with the controller and selected 1-based board index.

The dialog will prepopulate the controller’s current serial number and clamp the editable emitter count to the profile-derived maximum. Confirming a non-empty serial number will validate and normalize it through `SerialNumberHelper.GetSNr(serialNumber, 0)`, persist the base serial number and count only after validation succeeds, and return enough result data for a future caller to update its board display with the computed ending serial number. Empty input will clear the serial number, matching the MATLAB dialog. Cancel will leave controller state unchanged.

`BurnInProfile` will gain the missing `GetMaxNofEmitters` behavior from MATLAB: return zero unless a profile is loaded, otherwise sum both channel counts. `BurnInController` will expose the corresponding 1-based-board method for dialog consumers, delegating to that board’s profile. Validate board indices consistently at this public UI boundary.

**Progress**: 100% [██████████]

**Last Updated**: 2026-08-15 12:04:10

## 📝 Plan Steps
- ✅ **Add `BurnInApp/SerialNumberDialog.axaml` — define a non-resizable, owner-centered Avalonia modal with serial-number and last-position inputs, dynamic range labels, and OK/Cancel actions that mirror the MATLAB layout and limits.**
- ✅ **Add `BurnInApp/SerialNumberDialog.axaml.cs` — initialize the dialog from a `BurnInController` plus 1-based board index; clamp and validate emitter input; validate/normalize serial numbers with `SerialNumberHelper`; commit confirmed values; expose the computed serial-number range through the dialog result; and display validation errors without closing.**
- ✅ **Update `BurnInApp/BurnInProfile.cs` — add `IsProfileLoaded` if needed for parity and add `GetMaxNofEmitters` to return the combined configured channel capacity only for loaded profiles.**
- ✅ **Update `BurnInApp/BurnInController.cs` — add a public 1-based `GetMaxNofEmitters(int index)` delegating to the selected `BurnInProfile`, with index validation suitable for the dialog API.**
- ✅ **Build the .NET 10 Avalonia project — resolve XAML/code-behind compilation issues and verify the dialog’s serial validation, empty-value clearing, count clamping, and cancel-without-commit behavior.**

