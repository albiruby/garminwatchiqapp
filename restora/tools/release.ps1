<#
RESTORA release build for the Connect IQ Store.

Usage (PowerShell, from the project folder):
  # once: create your permanent signing key and back it up (keep it private,
  # never commit it; losing it means the Store app can never be updated)
  powershell -File tools\release.ps1 -NewKey C:\Keys\restora_release_key.der

  # every release: unit tests in the simulator, then the signed .iq package
  powershell -File tools\release.ps1 -Key C:\Keys\restora_release_key.der

Output: dist\RESTORA-<version>.iq (upload this file on developer.garmin.com).
#>
param(
    [string]$Key,
    [string]$NewKey,
    [switch]$SkipTests
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($NewKey) {
    if (Test-Path $NewKey) { throw "Key already exists: $NewKey (not overwritten)" }
    $dir = Split-Path -Parent $NewKey
    if ($dir) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $tmp = Join-Path $env:TEMP "RestoraGenKey.java"
    @'
import java.security.*; import java.nio.file.*;
public class RestoraGenKey { public static void main(String[] a) throws Exception {
 KeyPairGenerator g = KeyPairGenerator.getInstance("RSA"); g.initialize(4096);
 Files.write(Paths.get(a[0]), g.generateKeyPair().getPrivate().getEncoded()); } }
'@ | Set-Content $tmp -Encoding ascii
    java $tmp $NewKey
    Remove-Item $tmp
    Write-Host "Created $NewKey - back it up now (two places). Do not commit it."
    if (-not $Key) { exit 0 }
}

if (-not $Key) { throw "Pass -Key <path to your permanent .der key>" }
if (-not (Test-Path $Key)) { throw "Key not found: $Key" }

$sdk = (Get-ChildItem "$env:APPDATA\Garmin\ConnectIQ\Sdks" | Sort-Object Name | Select-Object -Last 1).FullName
$env:Path += ";$sdk\bin"
[xml]$m = Get-Content manifest.xml
$version = $m.manifest.application.version
New-Item -ItemType Directory -Force bin, dist | Out-Null

if (-not $SkipTests) {
    Write-Host "Unit tests (simulator) ..."
    if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) {
        Start-Process "$sdk\bin\connectiq.bat" -WindowStyle Minimized
        Start-Sleep 20
    }
    cmd /c "monkeyc -f monkey.jungle -d fr165 -o bin\restora-test.prg -y `"$Key`" --unit-test > bin\release-test-build.log 2>&1"
    if ($LASTEXITCODE -ne 0) { Get-Content bin\release-test-build.log | Select-String ERROR; throw "Test build failed" }
    cmd /c "monkeydo bin\restora-test.prg fr165 /t > bin\release-test.log 2>&1"
    $result = Get-Content bin\release-test.log -Tail 1
    Write-Host $result
    if ($result -notmatch "^PASSED") { throw "Unit tests failed - see bin\release-test.log" }
}

$out = "dist\RESTORA-$version.iq"
Write-Host "Release package $out ..."
cmd /c "monkeyc -f monkey.jungle -e -r -o `"$out`" -y `"$Key`" > bin\release-iq.log 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content bin\release-iq.log | Select-String ERROR; throw "Package build failed" }
Write-Host "Done: $out ($([math]::Round((Get-Item $out).Length / 1KB)) KB). Upload it on developer.garmin.com."
