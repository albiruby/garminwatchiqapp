# Builds Fish Tank for every watch in manifest.xml.
#   build.ps1                 build every device into bin\
#   build.ps1 -Run            build fr165 and load it in the simulator
#   build.ps1 -Test           build with unit tests and run them in the simulator
param(
    [switch]$Run,
    [switch]$Test,
    [string]$Device = "fr165",
    [string[]]$Only = @(),
    [string]$Key = "$env:USERPROFILE\.Garmin\ConnectIQ\developer_key.der"
)
# monkeyc prints type-check warnings on stderr; "Stop" would turn those into failures.
$ErrorActionPreference = "Continue"
$proj = Resolve-Path (Join-Path $PSScriptRoot "..")
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
$bin = Join-Path $proj "bin"
New-Item -ItemType Directory -Force $bin | Out-Null
$jungle = Join-Path $proj "monkey.jungle"

function Invoke-Build($dev, $out, $extra) {
    & "$sdk\bin\monkeyc.bat" -f $jungle -d $dev -o $out -y $Key -w @extra
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $dev" }
}

if ($Test) {
    $out = Join-Path $bin "FishTank-test.prg"
    Invoke-Build $Device $out @("--unit-test")
    if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) {
        Start-Process "$sdk\bin\connectiq.bat"; Start-Sleep -Seconds 6
    }
    & "$sdk\bin\monkeydo.bat" $out $Device /t
    exit $LASTEXITCODE
}

if ($Run) {
    $out = Join-Path $bin "FishTank-$Device.prg"
    Invoke-Build $Device $out @()
    if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) {
        Start-Process "$sdk\bin\connectiq.bat"; Start-Sleep -Seconds 6
    }
    & "$sdk\bin\monkeydo.bat" $out $Device
    exit $LASTEXITCODE
}

# every watch in manifest.xml (or: build.ps1 -Only fr965,fr265s)
$devices = Select-String -Path (Join-Path $proj "manifest.xml") -Pattern 'iq:product id="([^"]+)"' -AllMatches |
    ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
if ($Only) { $devices = $Only }
foreach ($d in $devices) {
    Invoke-Build $d (Join-Path $bin "FishTank-$d.prg") @()
    Write-Host "OK $d"
}
