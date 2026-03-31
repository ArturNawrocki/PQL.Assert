# Scripts

This folder contains utility scripts for the PQL.Assert project.

## Clear-NotebookOutputs.ps1

Clears all outputs and execution counts from Jupyter notebook files while preserving cell content.

### Usage

```powershell
# Clear outputs from a specific notebook
.\scripts\Clear-NotebookOutputs.ps1 -NotebookPath "examples\fabric-notebook\RunPQLAssertTests.ipynb"

# Clear outputs from all notebooks in a directory
.\scripts\Clear-NotebookOutputs.ps1 -NotebookPath "examples\**\*.ipynb"

# Preview changes without modifying files
.\scripts\Clear-NotebookOutputs.ps1 -NotebookPath "MyNotebook.ipynb" -WhatIf
```

### Parameters

- **NotebookPath**: Path to the notebook file(s) to clean. Supports wildcards.
- **WhatIf**: (Optional) Shows what would be changed without actually modifying files.

### When is it used?

Use this script before committing notebooks to version control to ensure that:
- No sensitive output data is included in the repository
- Notebooks remain clean and don't show unnecessary execution history
- Diffs are minimal and focused on actual code changes

The script removes:
- All cell outputs
- Execution counts  
- Execution metadata

Cell content, markdown, and notebook structure are preserved.

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
