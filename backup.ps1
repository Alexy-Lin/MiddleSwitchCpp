# One-click backup: copy main.cpp, *.h, *.rc into a timestamped folder next to this script.

$ErrorActionPreference = 'SilentlyContinue'

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $PSScriptRoot ("backup_" + $ts)
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$patterns = @("main.cpp", "*.h", "*.rc")
[int]$copied = 0

foreach ($pat in $patterns) {
    Get-ChildItem -Path $PSScriptRoot -Filter $pat -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $backupDir -Force
        $copied++
    }
}

Write-Host ("Backup folder: " + $backupDir)
if ($copied -gt 0) {
    Write-Host ("Files copied: " + $copied)
} else {
    Write-Host "No matching files found (main.cpp, *.h, *.rc)."
}

# Keep the window open when double-clicked
if ($Host.Name -match 'ConsoleHost') {
    Write-Host "Press Enter to exit..."
    [void][System.Console]::ReadLine()
}
