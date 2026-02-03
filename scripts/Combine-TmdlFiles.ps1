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
    
    # Add the content to the combined output
    $combinedContent += $content
    
    # Add a blank line separator between files (except for the last file)
    if ($file -ne $tmdlFiles[-1]) {
        $combinedContent += ""
    }
}

# Write the combined content to the output file
$outputDir = Split-Path $OutputFile -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$combinedContent -join "`n" | Set-Content -Path $OutputFile -NoNewline

Write-Host "Successfully combined files into: $OutputFile"
Write-Host "Total size: $((Get-Item $OutputFile).Length) bytes"
