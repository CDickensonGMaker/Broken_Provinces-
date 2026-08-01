<#
.SYNOPSIS
    Runs the content wiring validator and prints its verdict.

.DESCRIPTION
    Session gate for Broken Provinces. Run it when a session starts and again
    before committing anything under data/ or scripts/levels/ - it catches quest
    givers who were never spawned, reward items that do not exist, dead
    encounter-table entries and unreachable quest branches.

    Full findings land in docs/audits/validation_report.md.

.PARAMETER Godot
    Path to the Godot 4.5 binary. Defaults to the project's standard location.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/validate.ps1
#>
param(
    [string]$Godot = "$env:USERPROFILE\_tools\godot45\Godot_v4.5-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Godot)) {
    Write-Host "Godot 4.5 not found at: $Godot" -ForegroundColor Red
    Write-Host "Pass the binary explicitly: tools/validate.ps1 -Godot <path>"
    exit 2
}

$project = Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
    $output = & $Godot --headless --path . --script res://tools/validate_content.gd
    $verdict = $output | Select-String -Pattern '^Errors: '
    $counts = $output | Select-String -Pattern '^\| (NPC|Item|Enemy) ids discovered'

    foreach ($line in $counts) { Write-Host $line.Line }
    if ($verdict) {
        Write-Host ""
        if ($verdict.Line -match '^Errors: 0\b') {
            Write-Host $verdict.Line -ForegroundColor Green
        } else {
            Write-Host $verdict.Line -ForegroundColor Yellow
        }
    }
    Write-Host "Full report: docs/audits/validation_report.md"
    Write-Host "Known-and-accepted gaps: docs/audits/wave_b_dispositions.md"

    # Non-zero exit means errors exist. The count is not zero yet by design -
    # compare it against the last committed report before blaming your change.
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
