<#
.SYNOPSIS
    Clears all outputs and execution counts from Jupyter notebook files.

.DESCRIPTION
    This script removes all cell outputs, execution counts, and execution metadata
    from Jupyter notebook (.ipynb) files while preserving all cell content and structure.
    This is useful for cleaning notebooks before committing them to version control.

.PARAMETER NotebookPath
    The path to the notebook file (.ipynb) to clean. Can be a single file or use wildcards.

.PARAMETER WhatIf
    Shows what would be changed without actually modifying the file.

.EXAMPLE
    .\scripts\Clear-NotebookOutputs.ps1 -NotebookPath "examples\fabric-notebook\RunPQLAssertTests.ipynb"
    
    Clears all outputs from the specified notebook.

.EXAMPLE
    .\scripts\Clear-NotebookOutputs.ps1 -NotebookPath "examples\**\*.ipynb"
    
    Clears all outputs from all notebooks in the examples directory.

.EXAMPLE
    .\scripts\Clear-NotebookOutputs.psynb -NotebookPath "MyNotebook.ipynb" -WhatIf
    
    Shows what would be cleared without making changes.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$NotebookPath
)

function Clear-NotebookOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "Notebook file not found: $FilePath"
        return
    }

    Write-Host "Processing: $FilePath" -ForegroundColor Cyan

    try {
        # Read the notebook JSON
        $notebookContent = Get-Content $FilePath -Raw -Encoding UTF8
        $notebook = $notebookContent | ConvertFrom-Json

        $cellsModified = 0
        $outputsCleared = 0
        
        # Process each cell
        foreach ($cell in $notebook.cells) {
            $modified = $false

            # Clear outputs if present
            if ($cell.PSObject.Properties.Name -contains 'outputs') {
                if ($cell.outputs.Count -gt 0) {
                    $outputsCleared += $cell.outputs.Count
                    $modified = $true
                }
                $cell.outputs = @()
            }

            # Clear execution_count
            if ($cell.PSObject.Properties.Name -contains 'execution_count') {
                if ($null -ne $cell.execution_count) {
                    $modified = $true
                }
                $cell.execution_count = $null
            }

            # Clear execution metadata if present
            if ($cell.PSObject.Properties.Name -contains 'metadata') {
                if ($cell.metadata.PSObject.Properties.Name -contains 'execution') {
                    $cell.metadata.PSObject.Properties.Remove('execution')
                    $modified = $true
                }
            }

            if ($modified) {
                $cellsModified++
            }
        }

        if ($cellsModified -gt 0) {
            if ($PSCmdlet.ShouldProcess($FilePath, "Clear $outputsCleared output(s) from $cellsModified cell(s)")) {
                # Convert back to JSON with proper formatting
                $cleanedJson = $notebook | ConvertTo-Json -Depth 100 -Compress:$false
                
                # Save with UTF8 encoding (no BOM) and LF line endings to match Jupyter standard
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($FilePath, $cleanedJson, $utf8NoBom)
                
                Write-Host "  ✅ Cleared $outputsCleared output(s) from $cellsModified cell(s)" -ForegroundColor Green
            }
        } else {
            Write-Host "  ℹ️  No outputs to clear" -ForegroundColor Gray
        }
    }
    catch {
        Write-Error "Failed to process $FilePath : $_"
    }
}

# Resolve the path (handles wildcards and relative paths)
$resolvedPaths = Resolve-Path $NotebookPath -ErrorAction SilentlyContinue

if (-not $resolvedPaths) {
    Write-Error "No files found matching: $NotebookPath"
    exit 1
}

$notebookFiles = $resolvedPaths | Where-Object { $_.Path -like "*.ipynb" }

if ($notebookFiles.Count -eq 0) {
    Write-Error "No .ipynb files found matching: $NotebookPath"
    exit 1
}

Write-Host "`n🧹 Clearing notebook outputs..." -ForegroundColor Yellow
Write-Host "Found $($notebookFiles.Count) notebook(s) to process`n" -ForegroundColor Yellow

foreach ($file in $notebookFiles) {
    Clear-NotebookOutput -FilePath $file.Path
}

Write-Host "`n✅ Done!`n" -ForegroundColor Green
