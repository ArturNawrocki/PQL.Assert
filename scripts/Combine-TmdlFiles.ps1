#!/usr/bin/env pwsh
# Script to combine TMDL files from src/lib into a single functions.tmdl file
# This script is used during the publish-package workflow

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceDir,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

# Ensure the source directory exists
if (-not (Test-Path $SourceDir)) {
    Write-Error "Source directory not found: $SourceDir"
    exit 1
}

# Get all .tmdl files from the source directory, excluding the output file name
$tmdlFiles = Get-ChildItem -Path $SourceDir -Filter "*.tmdl" | 
    Where-Object { $_.Name -ne (Split-Path $OutputFile -Leaf) } |
    Sort-Object Name

if ($tmdlFiles.Count -eq 0) {
    Write-Error "No TMDL files found in: $SourceDir"
    exit 1
}

Write-Host "Found $($tmdlFiles.Count) TMDL file(s) to combine:"
$tmdlFiles | ForEach-Object { Write-Host "  - $($_.Name)" }

# Combine all files
$combinedContent = @()

foreach ($file in $tmdlFiles) {
    Write-Host "Processing: $($file.Name)"
    $content = Get-Content -Path $file.FullName -Raw
    
    # Remove createOrReplace statement (first line) and unindent the content
    $lines = $content -split "`r?`n"
    $processedLines = @()
    $skipFirstCreateOrReplace = $true
    
    foreach ($line in $lines) {
        # Skip the first "createOrReplace" line and the blank line after it
        if ($skipFirstCreateOrReplace -and $line -match '^\s*createOrReplace\s*$') {
            $skipFirstCreateOrReplace = $false
            continue
        }
        
        # Skip the blank line immediately after createOrReplace
        if (-not $skipFirstCreateOrReplace -and $line -match '^\s*$' -and $processedLines.Count -eq 0) {
            continue
        }
        
        # For other lines, remove one level of indentation (4 spaces or one tab)
        if ($line -match '^\t(.*)$') {
            $processedLines += $matches[1].TrimEnd()
        } elseif ($line -match '^    (.*)$') {
            $processedLines += $matches[1].TrimEnd()
        } else {
            $processedLines += $line.TrimEnd()
        }
    }
    
    # Trim trailing blank lines from this file's content
    while ($processedLines.Count -gt 0 -and $processedLines[-1] -match '^\s*$') {
        $processedLines = $processedLines[0..($processedLines.Count - 2)]
    }
    
    # Join processed lines and add to combined content
    $processedContent = $processedLines -join "`n"
    $combinedContent += $processedContent
}

# Write the combined content to the output file
$outputDir = Split-Path $OutputFile -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$finalContent = $combinedContent -join "`n`n"

# Sanitize: ensure exactly one blank line between annotation and doc comments
# This pattern matches: annotation line, any blank lines, then a line starting with ///
$finalContent = [regex]::Replace($finalContent, '(annotation\s+\w+\s*=\s*[^\n]+)\n+(\s*///)', "`$1`n`n`$2")

# Sanitize: collapse any runs of 3+ consecutive blank lines down to 2 blank lines (one visible blank line)
$finalContent = [regex]::Replace($finalContent, '(\n\s*\n){3,}', "`n`n")

# Remove any leading blank lines
$finalContent = $finalContent -replace '^(\s*\n)+', ''

# Remove any trailing blank lines and ensure no trailing newline
$finalContent = $finalContent -replace '(\n\s*)+$', ''

$finalContent | Set-Content -Path $OutputFile -NoNewline

Write-Host "Successfully combined files into: $OutputFile"
Write-Host "Total size: $((Get-Item $OutputFile).Length) bytes"

# --- Post-combination validation ---
Write-Host "`nValidating combined output for excessive blank lines..."
$validationContent = Get-Content -Path $OutputFile -Raw
$validationLines = $validationContent -split "`r?`n"
$consecutiveBlankCount = 0
$violations = @()

for ($i = 0; $i -lt $validationLines.Count; $i++) {
    if ($validationLines[$i] -match '^\s*$') {
        $consecutiveBlankCount++
        if ($consecutiveBlankCount -ge 3) {
            $violations += "Line $($i + 1): too many consecutive blank lines ($consecutiveBlankCount in a row)"
        }
    } else {
        $consecutiveBlankCount = 0
    }
}

# Check for leading blank line
if ($validationLines.Count -gt 0 -and $validationLines[0] -match '^\s*$') {
    $violations += "Line 1: file starts with a blank line"
}

if ($violations.Count -gt 0) {
    Write-Error "TMDL validation failed! Found $($violations.Count) blank line violation(s):"
    $violations | ForEach-Object { Write-Error "  $_" }
    exit 1
} else {
    Write-Host "Validation passed: no excessive blank lines found."
}
