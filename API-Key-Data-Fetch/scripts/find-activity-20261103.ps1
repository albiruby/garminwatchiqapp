$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$key = (Get-Content -LiteralPath 'D:\Garmin\API-Key-Data-Fetch\garmin-api-key.txt' -Raw).Trim()
$tokenUri = 'https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token'
$tok = Invoke-RestMethod -Method Post -Uri $tokenUri -Headers @{ Authorization = "ApiKey $key" } -ContentType 'application/json'
$tok = "$tok".Trim().Trim('"')
$h = @{ Authorization = "Bearer $tok" }
$base = 'https://personal.connectapi.garmin.com'

$u = "$base/activitylist-service/activities/search/activities?startDate=2026-11-14&endDate=2026-11-14&start=0&limit=50"
$resp = Invoke-RestMethod -Method Get -Uri $u -Headers $h
$utf8 = New-Object System.Text.UTF8Encoding($false)
$out = 'D:\Garmin\API-Key-Data-Fetch\data\activitylist-2026-11-14.json'
[IO.File]::WriteAllText($out, (ConvertTo-Json -InputObject @($resp) -Depth 12), $utf8)
"SAVED $out n=$(@($resp).Count)"
foreach ($a in @($resp)) {
  "$($a.activityId) | $($a.startTimeLocal) | $($a.activityName) | $($a.activityType.typeKey) | dist=$($a.distance) dur=$($a.duration) maxHR=$($a.maxHR)"
}
