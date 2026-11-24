$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$key = (Get-Content -LiteralPath 'D:\Garmin\API-Key-Data-Fetch\garmin-api-key.txt' -Raw).Trim()
$tokenUri = 'https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token'
$tok = Invoke-RestMethod -Method Post -Uri $tokenUri -Headers @{ Authorization = "ApiKey $key" } -ContentType 'application/json'
$tok = "$tok".Trim().Trim('"')
$h = @{ Authorization = "Bearer $tok" }
$base = 'https://personal.connectapi.garmin.com'
$from = [datetime]'2026-05-20'
$to = [datetime]'2026-11-20'
$all = @()
$cur = $from
while ($cur -le $to) {
  $end = $cur.AddDays(13)
  if ($end -gt $to) { $end = $to }
  $u = "$base/usersummary-service/v2/dailysummaries?startDate=$($cur.ToString('yyyy-MM-dd'))&endDate=$($end.ToString('yyyy-MM-dd'))"
  $resp = Invoke-RestMethod -Method Get -Uri $u -Headers $h -TimeoutSec 60
  $arr = @($resp.data)
  if ($arr.Count) { $all += $arr }
  "chunk $($cur.ToString('yyyy-MM-dd'))..$($end.ToString('yyyy-MM-dd')) days=$($arr.Count)"
  $cur = $end.AddDays(1)
  Start-Sleep -Milliseconds 250
}
$all = @($all | Sort-Object calendarDate -Unique)
$out = 'D:\Garmin\API-Key-Data-Fetch\data\daily-summaries-calories-2026-05-20_2026-11-20.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($out, (ConvertTo-Json -InputObject @($all) -Depth 12), $utf8)
"SAVED $out n=$($all.Count)"
$sample = $all | Select-Object -Last 1
"sample keys: " + (($sample | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) -join ',')
"calories sample: " + (ConvertTo-Json -InputObject $sample.calories -Compress -Depth 6)
