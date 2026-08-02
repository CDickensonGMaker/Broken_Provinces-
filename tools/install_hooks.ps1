<#
.SYNOPSIS
    Installs the content-validation pre-commit gate.

.DESCRIPTION
    Step 13 of the 25-step plan was "validator into the workflow: a
    pre-commit/session gate so phantom refs can never accumulate again." It was
    never installed, and the obvious install - dropping a file into .git/hooks/ -
    would have been a silent no-op, because this repository sets

        core.hooksPath = .beads/hooks

    so git never looks in .git/hooks at all. That is the same shape as every bug
    this audit has been hunting: a thing that exists, reports itself healthy, and
    does nothing.

    So the gate is appended to whatever core.hooksPath actually resolves to,
    below the beads-managed block, between its own markers. Idempotent: run it
    again and it replaces its own section, never duplicating and never touching
    the beads one.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/install_hooks.ps1
#>
param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

## Writes a shell script with LF endings and NO byte-order mark.
##
## Windows PowerShell 5.1's `Set-Content -Encoding utf8` emits a BOM, and a BOM
## in front of `#!/usr/bin/env sh` makes git refuse the hook outright with
## "cannot spawn ...: Exec format error". Learned the hard way.
function Write-HookFile {
    param([string]$Path, [string]$Content)
    $normalised = $Content -replace "`r`n", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $normalised, $utf8NoBom)
}

$project = Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
    $hooksPath = (& git config --get core.hooksPath)
    if ([string]::IsNullOrWhiteSpace($hooksPath)) {
        $hooksPath = Join-Path (& git rev-parse --git-dir) "hooks"
    }
    if (-not (Test-Path $hooksPath)) {
        New-Item -ItemType Directory -Force -Path $hooksPath | Out-Null
    }

    $hook = Join-Path $hooksPath "pre-commit"
    $begin = "# --- BEGIN BROKEN PROVINCES CONTENT GATE ---"
    $end = "# --- END BROKEN PROVINCES CONTENT GATE ---"

    $existing = ""
    if (Test-Path $hook) { $existing = Get-Content $hook -Raw }

    # Strip any previous install of our section, leaving everything else alone.
    $pattern = [regex]::Escape($begin) + "(?s).*?" + [regex]::Escape($end) + "\r?\n?"
    $existing = [regex]::Replace($existing, $pattern, "")

    if ($Uninstall) {
        Write-HookFile -Path $hook -Content $existing
        Write-Host "Removed the content gate from $hook" -ForegroundColor Yellow
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($existing)) {
        $existing = "#!/usr/bin/env sh`n"
    }
    if (-not $existing.EndsWith("`n")) { $existing += "`n" }

    $section = @"
$begin
# Managed by tools/install_hooks.ps1. Do not edit between these markers.
_bp_gate="`$(git rev-parse --show-toplevel)/tools/hooks/pre-commit-validate.sh"
if [ -f "`$_bp_gate" ]; then
    sh "`$_bp_gate" || exit 1
fi
$end
"@

    Write-HookFile -Path $hook -Content ($existing + $section + "`n")
    Write-Host "Installed the content gate into $hook" -ForegroundColor Green
    Write-Host "core.hooksPath is '$hooksPath' - note that .git/hooks/ is NOT consulted in this repo."
    Write-Host "Bypass a single commit with BP_SKIP_VALIDATE=1."
}
finally {
    Pop-Location
}
