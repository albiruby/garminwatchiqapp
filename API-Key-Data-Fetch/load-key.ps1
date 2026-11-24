# Load Garmin API key into the current PowerShell session.
# Usage: . 'D:\Garmin\API-Key-Data-Fetch\load-key.ps1'

$keyPath = Join-Path $PSScriptRoot 'garmin-api-key.txt'

if (-not (Test-Path -LiteralPath $keyPath)) {
    throw "Garmin API key file not found: $keyPath"
}

$env:GARMIN_API_KEY = (Get-Content -LiteralPath $keyPath -Raw).Trim()
Write-Host 'GARMIN_API_KEY loaded into this session.' -ForegroundColor Green
