$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$key = (Get-Content -LiteralPath 'D:\Garmin\API-Key-Data-Fetch\garmin-api-key.txt' -Raw).Trim()
$tokenUri = 'https://personal.connectapi.garmin.com/personalapitoken-service/personal-api/personal-api-key/token'
$tok = Invoke-RestMethod -Method Post -Uri $tokenUri -Headers @{ Authorization = "ApiKey $key" } -ContentType 'application/json'
$tok = "$tok".Trim().Trim('"')

$base = 'https://personal.connectapi.garmin.com'
$h = @{ Authorization = "Bearer $tok" }
$fitDir = 'D:\Garmin\API-Key-Data-Fetch\fit'
New-Item -ItemType Directory -Path $fitDir -Force | Out-Null

$acts = Get-Content -LiteralPath 'D:\Garmin\API-Key-Data-Fetch\data\activities.json' -Raw | ConvertFrom-Json
foreach ($a in $acts) {
    $id = $a.activityId
    $tmp = Join-Path $fitDir "$id.bin"
    try {
        Invoke-WebRequest -Uri "$base/download-service/files/activity/$id" -Headers $h -OutFile $tmp -UseBasicParsing | Out-Null
        $bytes = [IO.File]::ReadAllBytes($tmp)
        $sig = if ($bytes.Length -ge 12) { [Text.Encoding]::ASCII.GetString($bytes[8..11]) } else { '' }
        if ($sig -eq '.FIT') {
            Move-Item -LiteralPath $tmp -Destination (Join-Path $fitDir "$id.fit") -Force
            "OK  $id  FIT  $($bytes.Length) bytes"
        } elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B) {
            Move-Item -LiteralPath $tmp -Destination (Join-Path $fitDir "$id.zip") -Force
            Expand-Archive -LiteralPath (Join-Path $fitDir "$id.zip") -DestinationPath (Join-Path $fitDir $id) -Force
            "OK  $id  ZIP  $($bytes.Length) bytes"
        } else {
            "WARN $id  unknown  $($bytes.Length) bytes  sig=$sig"
        }
    } catch {
        $code = try { [int]$_.Exception.Response.StatusCode } catch { 0 }
        "FAIL $id http=$code $($_.Exception.Message)"
    }
    Start-Sleep -Milliseconds 200
}
"---FILES---"
Get-ChildItem -LiteralPath $fitDir -Recurse -File | Select-Object FullName,Length | Format-Table -AutoSize | Out-String
