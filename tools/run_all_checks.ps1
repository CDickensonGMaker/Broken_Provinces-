<#
.SYNOPSIS
    Runs every headless gate in one pass and prints one verdict.

.DESCRIPTION
    The session gate for Broken Provinces. `validate.ps1` covers content wiring;
    this runs it AND every `tools/check_*.tscn` probe, which are the guards that
    catch dropped save fields, unhandled objective types, rejected navmeshes,
    autoload calls that do not exist, and the rest.

    Exit code is non-zero if anything failed, so it can be used from a hook.

.PARAMETER Godot
    Path to the Godot 4.5 binary. Defaults to the project's standard location.

.PARAMETER SkipValidator
    Run only the check scenes.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/run_all_checks.ps1
#>
param(
    [string]$Godot = "$env:USERPROFILE\_tools\godot45\Godot_v4.5-stable_win64_console.exe",
    [switch]$SkipValidator
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Godot)) {
    Write-Host "Godot 4.5 not found at: $Godot" -ForegroundColor Red
    Write-Host "Pass the binary explicitly: tools/run_all_checks.ps1 -Godot <path>"
    exit 2
}

$project = Split-Path -Parent $PSScriptRoot
Push-Location $project
$failed = @()

try {
    if (-not $SkipValidator) {
        $output = & $Godot --headless --path . --script res://tools/validate_content.gd
        $verdict = ($output | Select-String -Pattern '^Errors: ' | Select-Object -Last 1)
        if ($verdict -and $verdict.Line -match '^Errors: 0\b') {
            Write-Host ("{0,-30} {1}" -f "validate_content", $verdict.Line) -ForegroundColor Green
        } else {
            $line = if ($verdict) { $verdict.Line } else { "no verdict line" }
            Write-Host ("{0,-30} {1}" -f "validate_content", $line) -ForegroundColor Red
            $failed += "validate_content"
        }
    }

    # Scratch probes are prefixed with an underscore and never gate.
    $scenes = Get-ChildItem (Join-Path $project "tools\check_*.tscn") |
        Where-Object { -not $_.Name.StartsWith("_") } |
        ForEach-Object { $_.BaseName } | Sort-Object

    # The probes deliberately provoke warnings (a bad faction id, a missing
    # rank) to prove they are caught, so their stderr is loud and expected. It
    # is captured rather than printed, and only shown when a probe fails.
    # ErrorActionPreference must relax first: in Windows PowerShell 5.1,
    # redirecting a native executable's stderr wraps each line in an
    # ErrorRecord, which under Stop would abort the loop on a harmless warning.
    $ErrorActionPreference = "Continue"

    foreach ($scene in $scenes) {
        $out = & $Godot --headless --path . "res://tools/$scene.tscn" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("{0,-30} PASS" -f $scene) -ForegroundColor Green
        } else {
            Write-Host ("{0,-30} FAIL" -f $scene) -ForegroundColor Red
            $out | Select-String -Pattern '^\s+- ' | Select-Object -First 8 | ForEach-Object {
                Write-Host "    $($_.Line.Trim())" -ForegroundColor Red
            }
            $failed += $scene
        }
    }

    Write-Host ""
    if ($failed.Count -eq 0) {
        Write-Host "All gates green." -ForegroundColor Green
        exit 0
    }
    Write-Host ("FAILED: " + ($failed -join ", ")) -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}
