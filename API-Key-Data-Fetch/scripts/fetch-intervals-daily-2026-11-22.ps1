$ErrorActionPreference = 'Stop'
$envFile = 'D:\Garmin\WorkoutMCP\.env'
$key = (Get-Content -LiteralPath $envFile | Where-Object { $_ -match '^INTERVALS_API_KEY=(.+)$' } | ForEach-Object { $Matches[1].Trim() })
if (-not $key) { 'KEY_MISSING'; exit 1 }
$bytes = [Text.Encoding]::ASCII.GetBytes("API_KEY:$key"); $key = $null
$h = @{ Authorization = "Basic $([Convert]::ToBase64String($bytes))" }
$date = '2026-11-22'
$url = "https://intervals.icu/api/v1/athlete/0/wellness?oldest=$date&newest=$date"
$d = Invoke-RestMethod -Method Get -Uri $url -Headers $h -TimeoutSec 60
$out = "D:\Garmin\API-Key-Data-Fetch\data\daily-$date\intervals-wellness.json"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($out, (ConvertTo-Json -InputObject @($d) -Depth 20), $utf8)
"SAVED n=$(@($d).Count)"
"OUT $out"
