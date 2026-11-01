param(
  [string]$File = '',
  [string]$Out = '',
  [string]$Save = '',
  [switch]$AllBars
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-Type -Path (Join-Path (Split-Path -Parent $here) 'HeroBot.cs') -ReferencedAssemblies System.Drawing

[HB]::Init()
if ($File -ne '') {
  $bmp = [HB]::LoadPng($File)
} else {
  $hwnd = [HB]::FindGameWindow('HerosLand')
  if ($hwnd -eq [IntPtr]::Zero) { throw 'Hero''s Land process not found' }
  $bmp = [HB]::CaptureClient($hwnd)
}
if ($Save -ne '') { $bmp.Save($Save, [System.Drawing.Imaging.ImageFormat]::Png) }
$w = $bmp.Width; $h = $bmp.Height
$scale = $h / 1080.0
"image ${w}x${h} scale=$scale"
$px = [HB]::ToPixels($bmp, [ref]$w, [ref]$h)
$bars = [HB]::FindBars($px, $w, $h, $scale)
"bars=$($bars.Count)"
$sc = [HB]::Classify($bars, $w, $h, $scale)
"monsters=$($sc.monsters.Count) players=$($sc.players.Count) named=$($sc.named.Count) allies=$($sc.allies.Count) self=$([bool]($sc.self -ne $null))"
if ($sc.stamina -ne $null) { "STA(plate) fill=$([math]::Round($sc.stamina.fill,2)) at y=$($sc.stamina.y0)-$($sc.stamina.y1)" }
if ($sc.hudStamina -ne $null) { "STA(hud)   fill=$([math]::Round($sc.hudStamina.fill,2)) x=$($sc.hudStamina.x0)-$($sc.hudStamina.x1) y=$($sc.hudStamina.y0)-$($sc.hudStamina.y1)" }
if ($sc.self -ne $null) { "SELF  x=$($sc.self.x0)-$($sc.self.x1) y=$($sc.self.y0)-$($sc.self.y1) fill=$([math]::Round($sc.self.fill,2))" }
foreach ($b in $sc.monsters) { "MON   x=$($b.x0)-$($b.x1) y=$($b.y0)-$($b.y1) fill=$([math]::Round($b.fill,2)) badge=$($b.badge) name=$($b.nameTag) stack=$($b.stacked)" }
foreach ($b in $sc.players) { "PLAY  x=$($b.x0)-$($b.x1) y=$($b.y0)-$($b.y1) fill=$([math]::Round($b.fill,2)) badge=$($b.badge) name=$($b.nameTag) stack=$($b.stacked)" }
foreach ($b in $sc.named)   { "NAMED x=$($b.x0)-$($b.x1) y=$($b.y0)-$($b.y1) col=$($b.ColorName()) fill=$([math]::Round($b.fill,2)) badge=$($b.badge) name=$($b.nameTag) stack=$($b.stacked)" }
foreach ($b in $sc.allies)  { "ALLY  x=$($b.x0)-$($b.x1) y=$($b.y0)-$($b.y1) fill=$([math]::Round($b.fill,2)) badge=$($b.badge) name=$($b.nameTag) stack=$($b.stacked)" }
if ($AllBars) {
  "--- all bars ---"
  foreach ($b in $bars) { "BAR   col=$($b.ColorName()) x=$($b.x0)-$($b.x1) y=$($b.y0)-$($b.y1) fill=$([math]::Round($b.fill,2)) badge=$($b.badge) name=$($b.nameTag) stack=$($b.stacked)" }
}
if ($Out -ne '') { [HB]::Annotate($bmp, $sc, $Out); "saved $Out" }
$bmp.Dispose()


