# Scripts

This folder contains utility scripts for the PQL.Assert project.

## Combine-TmdlFiles.ps1

Combines multiple TMDL files from the `src/lib` directory into a single `functions.tmdl` file.

### Usage

```powershell
.\scripts\Combine-TmdlFiles.ps1 -SourceDir "src\lib" -OutputFile "src\lib\functions.tmdl"
```

### Parameters

- **SourceDir**: The directory containing the TMDL files to combine
- **OutputFile**: The path where the combined file should be written

### When is it used?

This script is automatically executed during the `publish-package` GitHub Actions workflow before copying files to the DaxLib fork. It allows us to maintain separate source files for organization while publishing a single combined file.

### Source Files

Currently combines:
- `functions.tmdl` - Core assertion functions
- `functions-bp.tmdl` - Best practice validation functions

The files are combined in alphabetical order with blank line separators.
