$ErrorActionPreference = 'SilentlyContinue'
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg" -Raw).Trim()
# Push the app to the running simulator (non-blocking).
$job = Start-Job -ScriptBlock { param($m,$p) & $m $p fr165 *>&1 } -ArgumentList "$sdk\bin\monkeydo.bat", 'D:\Garmin\ReadyRun\bin\ReadyRun.prg'
Start-Sleep -Seconds 8
# Capture the simulator window by handle (works even when not focused).
$src = 'using System; using System.Runtime.InteropServices; using System.Drawing; public class Cap { [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f); [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); public struct RECT { public int L,T,R,B; } public static Bitmap Grab(IntPtr h){ RECT r; GetWindowRect(h,out r); int w=r.R-r.L, ht=r.B-r.T; Bitmap b=new Bitmap(w,ht); using(Graphics g=Graphics.FromImage(b)){ IntPtr dc=g.GetHdc(); PrintWindow(h,dc,2); g.ReleaseHdc(dc);} return b; } }'
Add-Type -TypeDefinition $src -Language CSharp -ReferencedAssemblies System.Drawing
$p = Get-Process simulator | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$out = if ($args[0]) { $args[0] } else { 'D:\Garmin\ReadyRun\bin\sim.png' }
[Cap]::Grab($p.MainWindowHandle).Save($out)
Write-Output ("saved " + $out)
