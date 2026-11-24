$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$key = (Get-Content -LiteralPath 'D:\Garmin\API-Key-Data-Fetch\garmin-api-key.txt' -Raw).Trim()
$tok = Invoke-RestMethod -Method Post -Uri 'https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token' -Headers @{ Authorization = "ApiKey $key" } -ContentType 'application/json'
$tok = "$tok".Trim().Trim('"')
$h = @{ Authorization = "Bearer $tok" }
$base = 'https://personal.connectapi.garmin.com'
$date = '2026-11-22'
$out = "D:\Garmin\API-Key-Data-Fetch\data\daily-$date"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$log = New-Object System.Collections.Generic.List[string]
function Get-G([string]$name, [string]$path) {
  try {
    $d = Invoke-RestMethod -Uri ($base + $path) -Headers $h -Method Get -TimeoutSec 60
    $json = ConvertTo-Json -InputObject $d -Depth 100
    [IO.File]::WriteAllText((Join-Path $out "$name.json"), $json, $utf8)
    $log.Add("OK   $name  $($json.Length) bytes")
    return $d
  } catch {
    $code = try { [int]$_.Exception.Response.StatusCode } catch { 0 }
    $log.Add("FAIL $name  http=$code  $($_.Exception.Message)")
    return $null
  }
}
Get-G 'user-settings' '/userprofile-service/userprofile/settings' | Out-Null
Get-G 'hr-zones' '/biometric-service/heartRateZones/v2?generateDefaults=true' | Out-Null
Get-G 'daily-v2' "/usersummary-service/v2/dailysummaries?startDate=$date&endDate=$date" | Out-Null
Get-G 'daily-legacy' "/usersummary-service/usersummary/daily?calendarDate=$date" | Out-Null
Get-G 'heart-rate' "/wellness-service/wellness/dailyHeartRate?date=$date" | Out-Null
Get-G 'sleep' "/sleep-service/sleep/dailySleepSummariesByDate?startDate=$date&endDate=$date" | Out-Null
Get-G 'sleep-data' "/wellness-service/wellness/dailySleepData?date=$date" | Out-Null
Get-G 'body-battery' "/wellness-service/wellness/bodyBattery/reports/daily?startDate=$date&endDate=$date&chunks=4" | Out-Null
Get-G 'hrv' "/hrv-service/hrv/daily/$date/$date" | Out-Null
Get-G 'spo2' "/wellness-service/wellness/daily/spo2acclimation/$date" | Out-Null
Get-G 'respiration' "/wellness-service/wellness/daily/respiration/$date" | Out-Null
Get-G 'stress' "/usersummary-service/stats/stress/daily/$date/$date" | Out-Null
Get-G 'steps' "/usersummary-service/stats/steps/daily/$date/$date" | Out-Null
Get-G 'hydration' "/usersummary-service/stats/hydration/daily/$date/$date" | Out-Null
Get-G 'weight' "/weight-service/weight/range/$date/$date?includeAll=true" | Out-Null
Get-G 'fitness-age' "/fitnessage-service/fitnessage/v2/$date?fullHistoryScan=true" | Out-Null
Get-G 'training-readiness' "/metrics-service/metrics/trainingreadiness/$date" | Out-Null
Get-G 'training-status' "/metrics-service/metrics/trainingstatus/aggregated/$date" | Out-Null
Get-G 'activities' "/activitylist-service/activities/search/activities?startDate=$date&endDate=$date&start=0&limit=50" | Out-Null
$log
"OUTDIR $out"
