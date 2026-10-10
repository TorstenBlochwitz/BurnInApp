# 🎯 Add linux-x86 build configuration and install guide

## Understanding
Add a linux-x86 build/runtime configuration across the solution's projects, then document how to build/install both desktop apps on Linux and Windows.
## Assumptions
- The solution uses SDK-style .NET 10 projects with Avalonia desktop apps and one shared library.
- A solution-wide MSBuild file is the least invasive place to add shared runtime/platform settings.
- The installation explanation should live in a repository document so it can be reused outside this chat.
## Approach
First verify the current solution structure and whether linux-x86 is a valid runtime target in the local SDK. Then add the smallest shared MSBuild configuration needed for all projects, while keeping app-specific behavior unchanged. Finally, add a deployment/install document covering publish steps, runtime prerequisites, config/data locations, and platform-specific launch/setup notes for both [BurnInApp/BurnInApp.csproj](BurnInApp/BurnInApp.csproj) and [BurnInBoardMaintenanceApp/BurnInBoardMaintenanceApp.csproj](BurnInBoardMaintenanceApp/BurnInBoardMaintenanceApp.csproj).

Because the solution is an `.slnx` with plain SDK projects and no existing custom configurations, a root-level build props file is likely the right integration point. The documentation should reflect actual app behavior from [BurnIn.Shared/BurnInPathProvider.cs](BurnIn.Shared/BurnInPathProvider.cs) and controller startup paths where settings files are created.
## Key Files
- BurnInApp/BurnInApp.csproj - primary desktop app project
- BurnInBoardMaintenanceApp/BurnInBoardMaintenanceApp.csproj - second desktop app project
- BurnIn.Shared/BurnIn.Shared.csproj - shared library that must participate in the same build settings
- BurnIn.Shared/BurnInPathProvider.cs - defines config/data locations used in install guidance
- BurnInApp.slnx - solution container for all projects
## Risks & Open Questions
- linux-x86 may not be supported by the installed .NET 10 SDK; if so, the plan must adapt to document the constraint instead of adding a broken configuration.
- Avalonia can run cross-platform, but Linux serial access may still require device permissions or a stable symlink for `/dev/ttyUSB-MBC`.

**Progress**: 100% [██████████]

**Last Updated**: 2026-10-10 16:40:38

## 📝 Plan Steps
- ✅ **Verify linux-x86 support**
- ✅ **Add shared build configuration**
- ✅ **Write installation guide**
- ✅ **Validate solution build**

