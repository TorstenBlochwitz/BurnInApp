# Restore Status Cell Backgrounds
## Understanding
Determine why the Status column does not reflect status colors, connect its cell background to the existing status-color logic, and validate the result.

## Assumptions
- The status text and its intended color are computed by `BurnInController`.
- `BoardRow` is the presentation model for `MainWindow`'s table.
- The existing DataGrid has no visual style that currently binds the Status column background.

## Approach
Inspect the table definition, `BoardRow`, and controller status APIs to identify the available color representation. Add the smallest presentation-model and XAML binding changes needed for the Status column, while keeping ordinary text and other columns unaffected. Then check diagnostics and build.

## Key Files
- [MainWindow.axaml](BurnInApp/MainWindow.axaml) - defines the Status column cell template.
- [MainWindow.axaml.cs](BurnInApp/MainWindow.axaml.cs) - updates each table row.
- [BurnInController.cs](BurnInApp/BurnInController.cs) - provides status information and colors.

## Risks & Open Questions
- Avalonia color values may need conversion to a brush for use as a cell background.

## Steps
1. Inspect status color data flow
2. Bind the Status cell background
3. Inspect changed-file diagnostics
4. Build the solution
5. Run relevant tests if available