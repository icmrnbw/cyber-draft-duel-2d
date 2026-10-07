param(
    [string]$Godot = "C:\Users\rnast\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
)

Set-StrictMode -Version Latest
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot executable not found: $Godot"
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "project.godot") -PathType Leaf)) {
    throw "Refusing to run outside a Godot project: $ProjectRoot"
}

Write-Host "Importing project-local textures under $ProjectRoot"
Write-Host "No files are deleted by this script."
& $Godot --path $ProjectRoot --headless --editor --quit-after 30
if ($LASTEXITCODE -ne 0) {
    throw "Godot editor import failed with exit code $LASTEXITCODE"
}
Write-Host "Godot import completed. Run the draft, ability, smoke, screenshot, and balance checks next."
