param(
    [string]$OldVersion = "0.3.0",
    [string]$NewVersion = "0.4.0"
)

$ErrorActionPreference = 'Stop'

Write-Host "Bumping PQL.Assert version from $OldVersion to $NewVersion..." -ForegroundColor Cyan

# Get repo root
$repoRoot = Split-Path $PSScriptRoot -Parent

# File patterns to update
$patterns = @(
    "$repoRoot\src\lib\*.tmdl",
    "$repoRoot\tests\model\TestingModel.SemanticModel\TMDLScripts\Load PQL*.tmdl",
    "$repoRoot\tests\model\TestingModel.SemanticModel\definition\functions.tmdl",
    "$repoRoot\tests\rls_model\RLS_Model.SemanticModel\definition\functions.tmdl"
)

$totalReplacements = 0
$filesModified = 0

foreach ($pattern in $patterns) {
    $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
    
    foreach ($file in $files) {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $originalContent = $content
        
        # Replace version
        $content = $content -replace "DAXLIB_PackageVersion = $OldVersion", "DAXLIB_PackageVersion = $NewVersion"
        
        if ($content -ne $originalContent) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            $replacements = ([regex]::Matches($originalContent, [regex]::Escape("DAXLIB_PackageVersion = $OldVersion"))).Count
            $totalReplacements += $replacements
            $filesModified++
            Write-Host "  ✓ Updated $($file.Name) ($replacements replacements)" -ForegroundColor Green
        }
    }
}

Write-Host "`nVersion bump complete!" -ForegroundColor Cyan
Write-Host "  Files modified: $filesModified" -ForegroundColor Green
Write-Host "  Total replacements: $totalReplacements" -ForegroundColor Green
