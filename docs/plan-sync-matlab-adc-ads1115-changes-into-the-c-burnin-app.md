# 🎯 Sync MATLAB ADC_ADS1115 changes into the C# BurnIn app

I compared `Matlab/ADC_ADS1115.m` with `BurnInApp/ADC_ADS1115.cs` and found that the C# `GetVoltageDiff` implementation has drifted substantially from MATLAB.

Grounded findings:
- `Matlab/ADC_ADS1115.m:53-149` now forces `configMux = ADS1115.CONFIG_MUX_SINGLE_0`, builds the ADC config in continuous mode (`0x0000` for mode), verifies the written config register, reads two conversion results, detects likely floating inputs when either reading exceeds `5.1`, and accepts the measurement when `abs(v1-v2) < max(0.01, 0.1 * max(abs(v1), abs(v2)))`.
- `BurnInApp/ADC_ADS1115.cs:69-147` still uses single-shot mode (`0x0100` plus OS bit), relies on `LastReadRaw` / raw-byte equality checks, and returns a single converted value from the first stable raw read. That no longer matches the MATLAB logic.
- `BurnInApp/BurnInDev.cs:148,175` already routes VDC measurements through `GetVoltageDiff(...)`, so those call sites are aligned with the MATLAB direction.
- `Matlab/BurnInDev.m:249-277` uses `getVoltageDiff(...)` for both VDC and resistor-voltage sampling inside `meas_R`, but `BurnInApp/BurnInDev.cs:205,214` still uses `GetVoltage(...)` there. That is the clearest nearby measurement drift to sync.
- `BurnInApp/ADS1115.cs:18-29` already contains the constants needed for the MATLAB-equivalent mux/mode configuration.
- Error propagation in C# already maps MATLAB-style controller errors through `MBC_USB_TCP.HandleError(...)` (`BurnInApp/MBC_USB_TCP.cs:830-837`), so the MATLAB `CBerror('029')` behavior can stay aligned without introducing a new mechanism.
- `BurnInApp.slnx` contains only the app project; I did not find a separate automated test project, so verification should rely on build validation plus targeted runtime/manual measurement checks.

Implementation intent:
- Make `ADC_ADS1115.GetVoltageDiff` behave like the MATLAB version as closely as practical.
- Remove or stop depending on the obsolete `LastReadRaw`-based validation if it becomes unused after the sync.
- Update nearby measurement code in `BurnInDev` where MATLAB has already switched from `getVoltage(...)` to `getVoltageDiff(...)`.
- Keep the existing C# exception-based error path (`HandleError("029")`) while matching MATLAB decision points.

Risks / watch items:
- Moving from the old C# single-shot flow to the MATLAB continuous-mode flow changes timing and acceptance criteria; any code that implicitly relied on the old retry behavior could observe different failures/successes.
- `GetVoltageDiff` currently ignores its incoming mux in MATLAB by forcing single-ended channel 0. That should be mirrored intentionally, and the C# comments/signature should make that explicit to avoid future confusion.
- After the sync, `LastReadRaw` may become dead state and should be removed only if no remaining code depends on it.

**Progress**: 100% [██████████]

**Last Updated**: 2026-10-10 13:14:55

## 📝 Plan Steps
- ✅ **Update `BurnInApp/ADC_ADS1115.cs` — replace the current `GetVoltageDiff` logic with the MATLAB-equivalent flow: force `CONFIG_MUX_SINGLE_0`, use continuous-mode config, verify the config register, read two samples, apply the floating-input threshold and tolerance check, and preserve retry/error behavior through `HandleError("029")`.**
- ✅ **Clean up ADC state/comments — remove or neutralize `LastReadRaw`-specific logic if it is no longer used, and adjust method comments to reflect that `GetVoltageDiff` now mirrors the newer MATLAB behavior rather than the older raw-repeat check.**
- ✅ **Sync nearby measurement code in `BurnInApp/BurnInDev.cs` — change `MeasR(...)` sampling to use `GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144)` for both VDC and VR reads, matching `Matlab/BurnInDev.m`.**
- ✅ **Verify impact surfaces — recheck all `GetVoltageDiff` call sites and the remaining `GetVoltage` uses so the plan does not accidentally alter unrelated measurement paths.**
- ✅ **Validate the result — build the app and do a focused manual sanity check of VDC / resistance measurement paths, with special attention to floating-input handling and retry/error behavior since no dedicated test project is present.**

