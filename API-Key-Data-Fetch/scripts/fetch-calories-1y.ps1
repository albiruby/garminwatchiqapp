$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$key = (Get-Content -LiteralPath 'D:\Garmin\API-Key-Data-Fetch\garmin-api-key.txt' -Raw).Trim()
$tok = Invoke-RestMethod -Method Post -Uri 'https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token' -Headers @{ Authorization = "ApiKey $key" } -ContentType 'application/json'
$tok = "$tok".Trim().Trim('"')
$h = @{ Authorization = "Bearer $tok" }
$base = 'https://personal.connectapi.garmin.com'
$from = [datetime]'2025-11-22'
$to = [datetime]'2026-11-22'
$outDir = 'D:\Garmin\API-Key-Data-Fetch\data\calories-1y'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

$daily = @()
$cur = $from
while ($cur -le $to) {
  $end = $cur.AddDays(13); if ($end -gt $to) { $end = $to }
  $u = "$base/usersummary-service/v2/dailysummaries?startDate=$($cur.ToString('yyyy-MM-dd'))&endDate=$($end.ToString('yyyy-MM-dd'))"
  $resp = Invoke-RestMethod -Method Get -Uri $u -Headers $h -TimeoutSec 60
  $arr = @($resp.data)
  if ($arr.Count) { $daily += $arr }
  "daily $($cur.ToString('yyyy-MM-dd'))..$($end.ToString('yyyy-MM-dd')) n=$($arr.Count)"
  $cur = $end.AddDays(1)
  Start-Sleep -Milliseconds 250
}
$daily = @($daily | Sort-Object calendarDate -Unique)
$dailyFile = Join-Path $outDir 'daily-summaries-2025-11-22_2026-11-22.json'
[IO.File]::WriteAllText($dailyFile, (ConvertTo-Json -InputObject @($daily) -Depth 12), $utf8)
"SAVED $dailyFile n=$($daily.Count)"

$acts = @()
$startIdx = 0
$limit = 100
do {
  $u = "$base/activitylist-service/activities/search/activities?startDate=$($from.ToString('yyyy-MM-dd'))&endDate=$($to.ToString('yyyy-MM-dd'))&start=$startIdx&limit=$limit"
  $resp = Invoke-RestMethod -Method Get -Uri $u -Headers $h -TimeoutSec 60
  $page = @($resp)
  $acts += $page
  "activities start=$startIdx got=$($page.Count) total=$($acts.Count)"
  $startIdx += $limit
  Start-Sleep -Milliseconds 300
} while ($page.Count -eq $limit)
$acts = @($acts | Sort-Object activityId -Unique)
$actFile = Join-Path $outDir 'activities-2025-11-22_2026-11-22.json'
[IO.File]::WriteAllText($actFile, (ConvertTo-Json -InputObject @($acts) -Depth 12), $utf8)
"SAVED $actFile n=$($acts.Count)"
