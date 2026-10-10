# Fix BurnInProfileViewerDlg layout and readability

## Understanding
Adjust the Avalonia BurnIn profile viewer so it matches the MATLAB layout more closely: general profile data above the table, the profile steps table below, improved font sizing/readability, a resizable window, and table cells that show text fully without the white clipping area on the right.

## Approach
The main work is in [BurnInApp/BurnInProfileViewerDlg.axaml](BurnInApp/BurnInProfileViewerDlg.axaml). I will reorder the grid rows to place file/bank/measurement controls above the table, enable resizing, enlarge the DataGrid fonts/row height/column widths, and switch table columns to template-based read-only text blocks so the display element fills the cell cleanly. The code-behind in [BurnInApp/BurnInProfileViewerDlg.axaml.cs](BurnInApp/BurnInProfileViewerDlg.axaml.cs) should remain mostly unchanged unless a minor hookup is needed.

## Key Files
- BurnInApp/BurnInProfileViewerDlg.axaml - layout, fonts, table presentation, resize behavior
- BurnInApp/BurnInProfileViewerDlg.axaml.cs - existing read-only population logic and row highlighting
- Matlab/BurnInProfileViewer.mlapp - source layout reference

## Risks & Open Questions
- Avalonia DataGrid visual behavior can vary by theme; template columns are the safest way to avoid clipped text/white trailing editor artifacts.
- Column sizing may still need small follow-up tuning after visual testing.

## Steps
1. Update BurnInProfileViewerDlg.axaml layout
2. Improve BurnInProfileViewerDlg.axaml table styling
3. Adjust BurnInProfileViewerDlg.axaml.cs only if required
4. Build the solution and verify changes