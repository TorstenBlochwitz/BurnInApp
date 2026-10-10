# 🎯 Extract a Reusable `BurnIn.Shared` Library Without Moving `BurnInController`

The current solution contains a single Avalonia app project, `BurnInApp/BurnInApp.csproj`, referenced by `BurnInApp.slnx`. The startup layer is thin (`Program.cs`, `App.axaml.cs`), while `MainWindow.axaml.cs` directly creates and drives `BurnInController` and also contains UI-only presentation state (`BoardRow`).

After the clarification that `BurnInBoardMaintenanceApp.mlapp` does **not** use `BurnInController`, the architecture boundary should change. `BurnInController` should no longer be treated as the primary shared facade. Instead, it should be classified as burn-in-app-specific orchestration that remains in `BurnInApp` during the first architectural extraction.

The best near-term architecture is:
- keep both C# apps in the same repository and solution,
- add a minimal shared class library first,
- move only the truly reusable non-UI classes into that library,
- preserve `BurnInApp` behavior with minimal breakage,
- avoid designing the shared layer around one app’s workflow controller.

Recommended target structure:
- `BurnInApp` — existing Avalonia burn-in UI and its app-specific orchestration
- `BurnIn.Shared` — new `net10.0` class library for reusable non-UI classes used by both apps
- optional later: `BurnIn.Shared.Tests` — tests for extracted shared logic
- optional later: a second app project for the maintenance Avalonia port, referencing `BurnIn.Shared`

Key architectural decision:
- Keep `BurnInController` in `BurnInApp` for phase 1.
- Extract the lower-level reusable building blocks it depends on.
- Let the future maintenance app build its own workflow/orchestration layer on top of `BurnIn.Shared`, instead of inheriting a burn-in-specific controller.

Recommended first extraction into `BurnIn.Shared`:
- hardware communication classes such as `MBC_TB`, `MBC_USB_TCP`, transport helpers, TCP helpers, I2C-related classes
- device/board abstractions such as `BurnInDev`, `DCDCConverterBoard`, `MainBoard`, ADC and related hardware helper classes
- shared support/persistence classes such as `BurnInSettings`, `StatusFile`, enums, value objects, profile/data/helper classes that do not depend on Avalonia
- any MATLAB-converted helper classes used by both apps, even if they are currently only referenced indirectly through `BurnInController`

Classes to keep in `BurnInApp` initially:
- `Program`, `App`, `MainWindow`, dialogs, XAML-backed types
- `BoardRow` and any UI-thread/view state classes
- `BurnInController`, because it represents burn-in workflow orchestration specific to this app
- any code that is directly about burn-in app flow rather than reusable hardware/domain capability

This yields a cleaner long-term shape:
- `BurnIn.Shared` = reusable domain/hardware/support layer
- `BurnInApp` = burn-in workflow UI plus `BurnInController`
- future maintenance app = its own UI/workflow layer reusing `BurnIn.Shared`

Cross-platform implications remain important because both future C# apps must run on Windows and x86 Linux:
- keep the shared library Avalonia-free and `net10.0`
- normalize path handling; current code uses literal `~/...` style paths in classes such as `BurnInController`, `BurnInSettings`, and `MBC_USB_TCP`, which should be replaced with proper .NET path resolution before or during extraction of shared classes
- keep serial and TCP communication inside the shared layer, but localize OS-specific behavior behind small seams where practical
- avoid Windows-only assumptions in default folders, port naming, and logging locations

Important consequence of this revised plan:
- `BurnInController` is no longer the extraction anchor.
- The extraction anchor becomes the reusable hardware/support substrate under `BurnInController`.
- `BurnInApp` should be refactored to consume `BurnIn.Shared`, but not emptied of its orchestration layer in phase 1.

Main risks:
- `BurnInController` may currently own some helper logic that really belongs in the shared layer, so dependency untangling will be needed during extraction
- `MainWindow.axaml.cs` currently reaches deeply into controller-owned data, so phase 1 should avoid broader MVVM or workflow redesign
- some shared classes may still carry `BurnInApp` naming or app-identity assumptions that should be neutralized gradually
- there is no test project yet, so moving hardware/support classes across projects has regression risk

Recommended staged outcome:
1. First milestone: create `BurnIn.Shared` and move reusable non-UI support/hardware classes there, while keeping `BurnInController` in `BurnInApp`.
2. Second milestone: make `BurnInApp` reference and consume the shared library cleanly with minimal API churn.
3. Third milestone: normalize paths/config/logging for Windows and Linux.
4. Fourth milestone: when the maintenance app is ported, create its own Avalonia workflow layer on top of `BurnIn.Shared` rather than reusing `BurnInController`.

**Progress**: 90% [█████████░]

**Last Updated**: 2026-10-10 15:01:32

## 📝 Plan Steps
- ✅ **Add `BurnIn.Shared` — create a new `net10.0` class library in the same solution and reference it from `BurnInApp`.**
- ✅ **Identify reusable classes — inventory the non-Avalonia hardware, board, communication, settings, logging, enum, profile, and helper classes that are shared candidates, explicitly excluding `BurnInController` from the first extraction.**
- ✅ **Move shared infrastructure — extract the reusable communication and device-support classes into `BurnIn.Shared` while preserving public APIs where practical.**
- ✅ **Keep orchestration local — retain `BurnInController` in `BurnInApp` and update it to consume types from `BurnIn.Shared` rather than moving it into the shared library.**
- ✅ **Keep UI local — leave `Program`, `App`, `MainWindow`, dialogs, XAML, and `BoardRow` inside the Avalonia app project.**
- ✅ **Stabilize namespaces — choose a minimal-change namespace strategy so the app compiles with mostly import/reference updates instead of workflow rewrites.**
- ✅ **Fix cross-platform path handling — replace literal `~/...` and other OS-specific folder assumptions in extracted shared code with proper .NET path resolution suitable for Windows and x86 Linux.**
- ✅ **Introduce thin seams — isolate app paths, settings persistence, logging targets, and transport creation behind small interfaces or factories only where needed to remove app-specific assumptions from `BurnIn.Shared`.**
- ⏭️ **Add regression coverage — introduce a test project for settings, path resolution, profile/data parsing, and shared helper logic that can be validated without hardware.**
- ✅ **Prepare the second app boundary — document that the future maintenance Avalonia app should implement its own orchestration layer on top of `BurnIn.Shared` instead of depending on `BurnInController`.**

