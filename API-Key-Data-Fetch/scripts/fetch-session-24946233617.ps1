$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$BASE_DIR = 'D:\Garmin\API-Key-Data-Fetch'
$id = '24946233617'

$key = (Get-Content -LiteralPath (Join-Path $BASE_DIR 'garmin-api-key.txt') -Raw).Trim()
$tokenUri = 'https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token'
$tok = Invoke-RestMethod -Method Post -Uri $tokenUri -Headers @{ Authorization = "ApiKey $key" } -ContentType 'application/json'
$tok = "$tok".Trim().Trim('"')
$h = @{ Authorization = "Bearer $tok" }
$base = 'https://personal.connectapi.garmin.com'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$dst = Join-Path $BASE_DIR "sessions\$id"
New-Item -ItemType Directory -Path $dst -Force | Out-Null

# 1) activity detail
$detail = Invoke-RestMethod -Method Get -Uri "$base/activity-service/activity/$id" -Headers $h
$detailFile = Join-Path $dst "activity-detail-$id.json"
[IO.File]::WriteAllText($detailFile, (ConvertTo-Json -InputObject $detail -Depth 20), $utf8)
"SAVED $detailFile"
"name=$($detail.activityName)  start=$($detail.startTimeLocal)  dist=$($detail.distance)  dur=$($detail.duration)  cal=$($detail.calories)  avgHR=$($detail.averageHR)  maxHR=$($detail.maxHR)"
"avgPace=$($detail.averageRunningCadenceInStepsPerMinute)  steps=$($detail.steps)  aerobic=$($detail.aerobicTrainingEffect)  anaerobic=$($detail.anaerobicTrainingEffect)"

# 2) download file
$tmp = Join-Path $dst "$id.bin"
Invoke-WebRequest -Uri "$base/download-service/files/activity/$id" -Headers $h -OutFile $tmp -UseBasicParsing | Out-Null
$bytes = [IO.File]::ReadAllBytes($tmp)
$sig = if ($bytes.Length -ge 12) { [Text.Encoding]::ASCII.GetString($bytes[8..11]) } else { '' }
"DL bytes=$($bytes.Length) sig=$sig"
if ($sig -eq '.FIT') {
    Move-Item -LiteralPath $tmp -Destination (Join-Path $dst "${id}_ACTIVITY.fit") -Force
    "OK FIT"
} elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B) {
    $zip = Join-Path $dst "$id.zip"
    Move-Item -LiteralPath $tmp -Destination $zip -Force
    Expand-Archive -LiteralPath $zip -DestinationPath $dst -Force
    Get-ChildItem -LiteralPath $dst -Recurse -File | Where-Object { $_.Extension -ieq '.fit' } | ForEach-Object { "ZIP_FIT $($_.Name) $($_.Length)" }
} else {
    "WARN unknown format"
}

"---FILES---"
Get-ChildItem -LiteralPath $dst -Recurse -File | Select-Object Name,Length | Format-Table -AutoSize | Out-String
