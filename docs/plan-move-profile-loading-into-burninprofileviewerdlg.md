# Move profile loading into BurnInProfileViewerDlg
## Understanding
Remove the standalone Load buttons from the main status table, show the row number in the first column, and move profile loading into the profile viewer dialog. The viewer should show a Load button where the File Name label was, and that button must use the same MATLAB enable rule: only enabled for EMPTY or READY_TO_RUN profiles.
## Approach
Update [MainWindow.axaml](BurnInApp/MainWindow.axaml) to remove the load column, add a row-number column, and keep the Profile button column as the entry point. Update [MainWindow.axaml.cs](BurnInApp/MainWindow.axaml.cs) so the Profile column shows `Load...` when no profile is loaded, always opens the viewer, refreshes after dialog close, and no longer owns the load workflow.

Update [BurnInProfileViewerDlg.axaml](BurnInApp/BurnInProfileViewerDlg.axaml) to replace the `File Name:` label with a `Load...` button. Update [BurnInProfileViewerDlg.axaml.cs](BurnInApp/BurnInProfileViewerDlg.axaml.cs) to accept controller and board index context, host the file picker/read logic previously in MainWindow, refresh the viewer after loading, and enable the load button only for EMPTY or READY_TO_RUN.
## Key Files
- BurnInApp/MainWindow.axaml - remove Load column and add row-number column
- BurnInApp/MainWindow.axaml.cs - move display/launch behavior and remove load handler ownership
- BurnInApp/BurnInProfileViewerDlg.axaml - add Load button in top row
- BurnInApp/BurnInProfileViewerDlg.axaml.cs - implement load workflow and button enable rule
## Risks & Open Questions
- Full build may be blocked if BurnInApp.exe is running; file-level errors should still be checked.
## Steps
1. Update MainWindow.axaml table columns
2. Update MainWindow.axaml.cs profile-view flow
3. Update BurnInProfileViewerDlg.axaml top-row controls
4. Update BurnInProfileViewerDlg.axaml.cs load workflow
5. Validate edited files and build