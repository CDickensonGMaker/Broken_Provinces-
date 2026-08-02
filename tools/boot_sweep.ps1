<#
.SYNOPSIS
    Boots every level scene headless and records every error/warning line.

.DESCRIPTION
    The sweep the 4.5 -> 4.7 migration ran by hand, made permanent. Each level
    scene under scenes/levels/ is loaded on its own in a headless run and quit
    after 90 frames; everything the engine prints is collected, grouped by
    scene, and also normalised into classes (paths, uids and numbers stripped)
    so two runs can be compared line for line.

    The output file is a baseline. Run it before a large mechanical change, run
    it again after, and diff the class table: the contract is zero NEW classes
    and no class getting louder. It is not a pass/fail gate on its own, because
    the tree has known-and-documented noise - leaked ObjectDB instances at exit
    is a nondeterministic engine teardown race, not a per-scene defect.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/boot_sweep.ps1 -Report baseline.txt
#>
param(
    [string]$Godot = "$env:USERPROFILE\_tools\godot47\Godot_v4.7-stable_win64_console.exe",
    [string]$Report = "boot_sweep.txt",
    [string]$LevelsDir = "scenes/levels"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $Godot)) {
    Write-Host "Godot 4.7 not found at: $Godot" -ForegroundColor Red
    exit 2
}

$project = Split-Path -Parent $PSScriptRoot
$reportPath = $Report
if (-not [System.IO.Path]::IsPathRooted($reportPath)) {
    $reportPath = Join-Path (Get-Location).Path $reportPath
}

$dir = Join-Path $project $LevelsDir
if (-not (Test-Path $dir)) {
    Write-Host "No levels dir: $dir" -ForegroundColor Red
    exit 2
}

$scratch = Join-Path $env:TEMP ("bp_boot_sweep_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $scratch | Out-Null

$scenes = Get-ChildItem -Path $dir -Filter *.tscn | Sort-Object Name
$rows = New-Object System.Collections.Generic.List[string]
$allLines = New-Object System.Collections.Generic.List[string]

foreach ($s in $scenes) {
    $res = "res://$LevelsDir/$($s.Name)"
    $stem = Join-Path $scratch $s.BaseName
    $proc = Start-Process -FilePath $Godot `
        -ArgumentList "--headless", "--path", $project, "--quit-after", "90", $res `
        -RedirectStandardOutput "$stem.out" -RedirectStandardError "$stem.err" `
        -PassThru -NoNewWindow
    if (-not $proc.WaitForExit(90000)) {
        try { $proc.Kill() } catch {}
        $rows.Add("##### $($s.Name)  [TIMEOUT]")
        $allLines.Add("TIMEOUT")
        Write-Host ("{0,-44} TIMEOUT" -f $s.BaseName) -ForegroundColor Yellow
        continue
    }
    $text = @()
    foreach ($f in @("$stem.out", "$stem.err")) {
        if (Test-Path $f) { $text += Get-Content $f -ErrorAction SilentlyContinue }
    }
    $bad = $text | Where-Object { $_ -match '^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING)' }

    $rows.Add("##### $($s.Name)")
    foreach ($b in $bad) {
        $rows.Add($b.TrimEnd())
        $allLines.Add($b.TrimEnd())
    }
    Write-Host ("{0,-44} {1}" -f $s.BaseName, $bad.Count)
}

# Normalise so the same defect in two scenes collapses to one class and the
# counts are comparable across a move that renamed everything.
$classes = @{}
foreach ($l in $allLines) {
    $c = $l -replace 'res://[^ ,"'']+', '<PATH>'
    $c = $c -replace 'uid://[A-Za-z0-9]+', '<UID>'
    $c = $c -replace '0x[0-9a-f]+', '<ADDR>'
    $c = $c -replace '\d+', 'N'
    if (-not $classes.ContainsKey($c)) { $classes[$c] = 0 }
    $classes[$c] = $classes[$c] + 1
}

$head = New-Object System.Collections.Generic.List[string]
$head.Add("# boot sweep")
$head.Add("scenes: $($scenes.Count)")
$head.Add("total lines: $($allLines.Count)")
$head.Add("classes: $($classes.Count)")
$head.Add("")
$head.Add("## classes")
foreach ($k in ($classes.Keys | Sort-Object)) {
    $head.Add(("{0,6}  {1}" -f $classes[$k], $k))
}
$head.Add("")
$head.Add("## per scene")

($head + $rows) | Out-File -LiteralPath $reportPath -Encoding utf8
Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "scenes: $($scenes.Count)  total lines: $($allLines.Count)  classes: $($classes.Count)"
Write-Host "wrote $reportPath"
exit 0
