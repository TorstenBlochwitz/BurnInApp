# 🎯 Add MSIX and tar.gz packaging

## Understanding
Prepare Windows MSIX packaging and Linux tar.gz packaging for both desktop apps in this solution, then update the installation guide to document the new packaging flow.
## Assumptions
- Packaging should be prepared for both `BurnInApp` and `BurnInBoardMaintenanceApp` as separate distributables.
- A script-based packaging flow is acceptable if it is repeatable from the repository without requiring ad hoc manual steps.
- MSIX packaging may require Windows-only tooling and signing setup that can be documented even if full package generation cannot be validated in this environment.
## Approach
First inspect the solution for app metadata such as versions, icons, and existing publish settings. Then add Windows packaging assets for MSIX and Linux packaging scripts for tar.gz archives. Keep packaging logic external to the app projects where possible, using a packaging project or scripts under a dedicated folder. Finally update `INSTALL.md` to explain how to build, package, install, and launch both apps on Windows and Linux.
## Key Files
- BurnInApp/BurnInApp.csproj - Windows/Linux publish source for the main app
- BurnInBoardMaintenanceApp/BurnInBoardMaintenanceApp.csproj - publish source for the maintenance app
- BurnInApp.slnx - solution container that may need packaging project entries
- INSTALL.md - installation and packaging documentation to update
## Risks & Open Questions
- MSIX generation may require Visual Studio packaging targets or signing setup that are not installed in this environment.
- Avalonia assets may not include dedicated icons yet; packaging may need placeholder assets generated from existing files or neutral defaults.

**Progress**: 100% [██████████]

**Last Updated**: 2026-10-10 18:50:51

## 📝 Plan Steps
- ✅ **Inspect packaging metadata**
- ✅ **Add MSIX packaging assets**
- ✅ **Add Linux tar.gz packaging scripts**
- ✅ **Update installation guide**
- ✅ **Validate packaging-related changes**

