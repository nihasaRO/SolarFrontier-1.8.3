# Builds bin\SolarFrontier.prg, for the Instinct 3 Solar by default (45 mm and 50 mm share one target).
# Usage:  .\build.ps1                      (release build)
#         .\build.ps1 -Sim                 (build, then open it in the Connect IQ simulator)
#         .\build.ps1 -Device instinct2 -Sim   (the same for the Instinct 2; or instinct2x for the Instinct 2X)
#         .\build.ps1 -Export              (store package bin\SolarFrontier.iq with every device in manifest.xml)
param([switch]$Sim, [switch]$Export, [string]$Device = "instinct3solar45mm")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$Out = "bin\SolarFrontier.prg"
$Key = if ($env:CONNECTIQ_DEVELOPER_KEY) { $env:CONNECTIQ_DEVELOPER_KEY } else { Join-Path $env:USERPROFILE ".connectiq\developer_key.der" }

# 1. Find the SDK: $env:CONNECTIQ_SDK, else the one selected in SDK Manager.
$Sdk = $env:CONNECTIQ_SDK
if (-not $Sdk) {
  $Cfg = Join-Path $env:APPDATA "Garmin\ConnectIQ\current-sdk.cfg"
  if (Test-Path $Cfg) { $Sdk = (Get-Content $Cfg -Raw).Trim() }
}
if (-not $Sdk -or -not (Test-Path (Join-Path $Sdk "bin\monkeyc.bat"))) {
  throw "Connect IQ SDK not found. Install it with Garmin's SDK Manager, or set `$env:CONNECTIQ_SDK to the SDK folder."
}

# 2. Developer key.
if (-not (Test-Path $Key)) {
  $Pem = [System.IO.Path]::ChangeExtension($Key, ".pem")
  if (Get-Command openssl -ErrorAction SilentlyContinue) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Key) | Out-Null
    openssl genrsa -out $Pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER -in $Pem -out $Key -nocrypt
  } else {
    throw "No developer key at $Key. In VS Code run 'Monkey C: Generate a Developer Key' and save it there, or set `$env:CONNECTIQ_DEVELOPER_KEY."
  }
}

# 3. Compile.
New-Item -ItemType Directory -Force -Path "bin" | Out-Null
if ($Export) {
  & (Join-Path $Sdk "bin\monkeyc.bat") -e -r -O 2z -f monkey.jungle -y $Key -o "bin\SolarFrontier.iq"
  if ($LASTEXITCODE -ne 0) { throw "Export failed (exit code $LASTEXITCODE)." }
  Write-Host "Exported bin\SolarFrontier.iq  ->  upload it at apps.garmin.com (Developer > Upload an app)" -ForegroundColor Green
  return
}
& (Join-Path $Sdk "bin\monkeyc.bat") -r -O 2z -f monkey.jungle -d $Device -y $Key -o $Out
if ($LASTEXITCODE -ne 0) { throw "Build failed (exit code $LASTEXITCODE)." }
Write-Host "Built $Out  ->  copy it to GARMIN\APPS on the watch" -ForegroundColor Green

if ($Sim) {
  Start-Process (Join-Path $Sdk "bin\simulator.exe")
  Start-Sleep -Seconds 4
  & (Join-Path $Sdk "bin\monkeydo.bat") $Out $Device
}
