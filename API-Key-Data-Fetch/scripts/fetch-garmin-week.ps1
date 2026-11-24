$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$key = (Get-Content -LiteralPath 'D:\Garmin\API-Key-Data-Fetch\garmin-api-key.txt' -Raw).Trim()
$tokenUri = 'https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token'
$tok = Invoke-RestMethod -Method Post -Uri $tokenUri -Headers @{ Authorization = "ApiKey $key" } -ContentType 'application/json'
$tok = "$tok".Trim().Trim('"')

$base = 'https://personal.connectapi.garmin.com'
$h = @{ Authorization = "Bearer $tok" }
$from = '2026-10-19'
$to = '2026-10-25'
$outDir = Join-Path $PSScriptRoot '..\data'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$log = New-Object System.Collections.Generic.List[string]

function Save-Resp([string]$name, $data) {
    $json = $data | ConvertTo-Json -Depth 100
    Set-Content -LiteralPath (Join-Path $outDir "$name.json") -Value $json -Encoding UTF8
    return $json.Length
}

function Get-G([string]$name, [string]$path) {
    try {
        $d = Invoke-RestMethod -Uri ($base + $path) -Headers $h -Method Get -TimeoutSec 60
        $len = Save-Resp $name $d
        $log.Add("OK   $name  $len bytes")
        return $d
    } catch {
        $code = try { [int]$_.Exception.Response.StatusCode } catch { 0 }
        $msg = $_.Exception.Message
        $log.Add("FAIL $name  http=$code  $msg")
        return $null
    }
}

$log.Add("AUTH OK")

# User + config
Get-G 'user-settings' '/userprofile-service/userprofile/settings' | Out-Null
Get-G 'hr-zones' '/biometric-service/heartRateZones/v2?generateDefaults=true' | Out-Null

# Daily summaries (rich)
Get-G 'daily-summaries-v2' "/usersummary-service/v2/dailysummaries?startDate=$from&endDate=$to" | Out-Null

# Legacy daily summary (per day, flatter)
for ($d = [datetime]'2026-10-19'; $d -le [datetime]'2026-10-25'; $d = $d.AddDays(1)) {
    $ds = $d.ToString('yyyy-MM-dd')
    Get-G "daily-summary-$ds" "/usersummary-service/usersummary/daily?calendarDate=$ds" | Out-Null
}

# Range stats
Get-G 'steps-daily' "/usersummary-service/stats/steps/daily/$from/$to" | Out-Null
Get-G 'stress-daily' "/usersummary-service/stats/stress/daily/$from/$to" | Out-Null
Get-G 'hydration-daily' "/usersummary-service/stats/hydration/daily/$from/$to" | Out-Null

# Sleep
Get-G 'sleep-summaries' "/sleep-service/sleep/dailySleepSummariesByDate?startDate=$from&endDate=$to" | Out-Null

# Body battery
Get-G 'body-battery' "/wellness-service/wellness/bodyBattery/reports/daily?startDate=$from&endDate=$to&chunks=4" | Out-Null

# HRV
Get-G 'hrv-daily' "/hrv-service/hrv/daily/$from/$to" | Out-Null

# Weight / body composition
Get-G 'weight-range' "/weight-service/weight/range/$from/$to?includeAll=true" | Out-Null
Get-G 'weight-all' "/weight-service/weight/all/$from/$to" | Out-Null

# Fitness age
Get-G 'fitness-age' "/fitnessage-service/fitnessage/v2/$to?fullHistoryScan=true" | Out-Null

# Goals
Get-G 'weight-goals' "/goal-service/goal/user/effective/weightgoal/$from/$to" | Out-Null

# Activities
$acts = Get-G 'activities' "/activitylist-service/activities/search/activities?startDate=$from&endDate=$to&limit=100&start=0&sortOrder=desc"
if ($acts) {
    $ids = @($acts | ForEach-Object { $_.activityId })
    $log.Add("ACTIVITY_COUNT $($ids.Count)")
    foreach ($id in $ids) {
        Get-G "activity-$id" "/activity-service/activity/$id" | Out-Null
    }
}

# Wellness activities
Get-G 'wellness-activities' "/wellnessactivity-service/activity/summary/range/$from/$to" | Out-Null

# Per-day wellness (HR, SpO2, nutrition, menstrual)
for ($d = [datetime]'2026-10-19'; $d -le [datetime]'2026-10-25'; $d = $d.AddDays(1)) {
    $ds = $d.ToString('yyyy-MM-dd')
    Get-G "daily-hr-$ds" "/wellness-service/wellness/dailyHeartRate?date=$ds" | Out-Null
    Get-G "spo2-$ds" "/wellness-service/wellness/daily/spo2acclimation/$ds" | Out-Null
    Get-G "nutrition-$ds" "/nutrition-service/food/logs/$ds" | Out-Null
    Start-Sleep -Milliseconds 120
}
Get-G 'menstrual-summary' "/periodichealth-service/menstrualcycle/summary/$to" | Out-Null

$log | ForEach-Object { $_ }
"OUTDIR $outDir"
