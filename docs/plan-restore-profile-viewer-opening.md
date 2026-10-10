# Restore Profile Viewer Opening
## Understanding
Investigate why clicking a status-table cell after loading a profile does not open `BurnInProfileViewerDlg`, then correct the event or dialog initialization path and validate the build.

## Assumptions
- The status table is implemented in `MainWindow.axaml` and its code-behind.
- Profile loading and dialog display are handled by existing application code.
- The fix should preserve the current UI behavior apart from restoring the dialog opening.

## Approach
Trace the table’s pointer/selection event from `MainWindow.axaml` into its code-behind, then inspect the dialog constructor and profile state model. Identify the condition or binding mismatch preventing the dialog from being displayed after a profile load. Apply the smallest correction and validate compilation and relevant tests if present.

## Key Files
- [MainWindow.axaml](BurnInApp/MainWindow.axaml) - defines the status table and its interaction handlers.
- [MainWindow.axaml.cs](BurnInApp/MainWindow.axaml.cs) - handles status interactions and opens dialogs.
- [BurnInProfileViewerDlg.axaml.cs](BurnInApp/BurnInProfileViewerDlg.axaml.cs) - initializes the profile viewer dialog.
- [BurnInProfile.cs](BurnInApp/BurnInProfile.cs) - defines loaded profile state.

## Risks & Open Questions
- The failure could be caused by an unobserved exception in an async event handler; the interaction path will determine whether error handling is needed.

## Steps
1. Inspect status-table interaction wiring
2. Trace profile loading and dialog initialization
3. Correct the dialog-opening failure
4. Inspect changed-file diagnostics
5. Build the solution
6. Run relevant tests if available