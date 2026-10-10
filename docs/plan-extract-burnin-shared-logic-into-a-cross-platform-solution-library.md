# 🎯 Extract BurnIn Shared Logic into a Cross-Platform Solution Library

The current solution contains a single Avalonia app project (`BurnInApp/BurnInApp.csproj`) and no shared library. The UI entry points are thin (`Program.cs`, `App.axaml.cs`), but the main window currently constructs and drives `BurnInController` directly (`BurnInApp/MainWindow.axaml.cs:19,33`) and also owns UI-only row state (`BoardRow` in the same file). Most of the future-shareable logic already exists outside Avalonia in classes such as `BurnInController`, `BurnInDev`, `MBC_TB`, `MBC_USB_TCP`, `BurnInSettings`, and `StatusFile`.

Given the user choices, the best near-term architecture is:
- keep both C# apps in the same repository/solution,
- extract a minimal shared class library first,
- preserve the current public surface as much as practical,
- define boundaries so the library can later be split further or packaged without rework.

Recommended target structure:
- `BurnInApp` — Avalonia UI/composition root for the existing app
- `BurnIn.Shared` — new `net10.0` class library containing reusable non-UI logic
- optional later: `BurnIn.Shared.Tests` — unit tests for extracted logic

Minimal first extraction scope:
- move non-Avalonia classes from `BurnInApp` into `BurnIn.Shared`
- keep namespace compatibility initially, or introduce a root namespace with compatibility wrappers if needed
- leave app-specific UI classes in the Avalonia app (`MainWindow`, dialogs, `BoardRow`, XAML)
- keep `BurnInController` as the initial facade so `MainWindow` can keep calling nearly the same API during phase 1

Suggested contents for `BurnIn.Shared` in the first phase:
- orchestration/domain classes: `BurnInController`, `BurnInDev`, `BurnInAction`, `BurnInStatus`, `BurnInProfile`, related enums/value types
- hardware communication classes: `MBC_TB`, `MBC_USB_TCP`, board/device classes, TCP helpers
- persistence/support classes: `BurnInSettings`, `StatusFile`
- any profile parsing, measurement, logging, and helper classes that do not depend on Avalonia

Classes to keep in `BurnInApp` initially:
- `Program`, `App`, `MainWindow`, dialogs, XAML-backed controls
- `BoardRow` and other Avalonia-specific presentation models
- any file pickers, dialogs, dispatch timers, and UI-thread coordination

Boundary rules for the extraction:
- `BurnIn.Shared` must not reference Avalonia.
- The app may reference `BurnIn.Shared`, but not the reverse.
- App startup should become the composition root that creates `BurnInController` and passes configuration/UI callbacks if needed.
- File system, serial/TCP, and settings access may remain in the shared library initially, but should be isolated behind small interfaces where practical to reduce future coupling.

Cross-platform requirements to address during the architecture change:
- replace hardcoded or shell-style paths with .NET path resolution based on `Environment.SpecialFolder`, `Environment.GetEnvironmentVariable("HOME")`, or a dedicated path service; current code uses literal `~/...` in `BurnInController`, `BurnInSettings`, and `MBC_USB_TCP`, which is not automatically expanded by .NET
- keep `System.IO.Ports` usage inside the shared layer, but isolate port discovery/opening behind a transport abstraction so Linux and Windows differences stay localized
- avoid any Windows-only assumptions in default folders, status logging, or port naming
- ensure all new projects target `net10.0` so both apps remain aligned on x86 Linux and Windows

State-of-the-art direction without overengineering phase 1:
- use a shared library project reference now, not copy-pasted classes
- define internal architectural seams now for later evolution: `ISettingsStore`, `IStatusLogger`, `IMbcTransport`/`IMbcConnectionFactory`, `IAppPaths` as needed
- keep `BurnInController` as the anti-corruption facade during extraction, then later split responsibilities only after both apps compile against the shared library
- once the second app starts, place its Avalonia UI in a separate app project that consumes the same shared library

Main risks found in the current codebase:
- the controller is large (`BurnInController.cs`) and acts as both workflow orchestrator and composition point, so some dependencies will move together in phase 1
- UI currently reaches deep into controller-owned arrays and statuses from `MainWindow.axaml.cs`, so preserving API shape is important to avoid a wide UI rewrite now
- some defaults are app-branded (`BurnInApp` paths and folders), so the shared layer needs neutral naming or caller-provided app identity before a second app is added
- the solution currently lacks a test project, so regression risk rises when moving hardware and settings code across project boundaries

Recommended staged outcome:
1. First milestone: shared logic compiles in `BurnIn.Shared`; existing `BurnInApp` runs unchanged except for project references and namespace/import updates.
2. Second milestone: path/config/logging concerns are normalized for Windows and Linux.
3. Third milestone: when the maintenance app is started, create its Avalonia project and consume the shared library rather than duplicating converted MATLAB classes.

**Last Updated**: 2026-10-10 14:39:04

## 📝 Plan Steps
-  **Add `BurnIn.Shared` — create a new `net10.0` class library in the same solution and reference it from `BurnInApp`.**
-  **Move reusable classes — extract non-Avalonia classes from `BurnInApp` into `BurnIn.Shared` while preserving public APIs wherever possible.**
-  **Keep UI local — leave `Program`, `App`, `MainWindow`, dialogs, XAML, and `BoardRow` inside the Avalonia app project.**
-  **Stabilize namespaces — choose a minimal-change namespace strategy so `BurnInApp` can compile with mostly import/reference updates instead of behavioral rewrites.**
-  **Introduce thin seams — isolate app paths, settings storage, logging, and MBC transport creation behind small interfaces or factories only where needed to remove app-specific assumptions.**
-  **Fix cross-platform path handling — replace literal `~/...` and other OS-specific folder assumptions with proper .NET path resolution suitable for Windows and x86 Linux.**
-  **Make the app the composition root — instantiate shared services from `BurnInApp` startup/UI and keep the shared library free of Avalonia dependencies.**
-  **Verify runtime dependencies — confirm serial/TCP communication and file/log creation remain functional on both Windows and Linux after the project split.**
-  **Add regression coverage — introduce a test project for settings, path resolution, profile parsing, and controller logic that can be validated without hardware.**
-  **Prepare the second app boundary — document that the future `BurnInBoardMaintenanceApp` Avalonia port should reference `BurnIn.Shared` directly instead of re-owning duplicated helper classes.**

