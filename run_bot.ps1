# run_bot.ps1 -- Hero's Land auto farm bot
#   MOVE: WASD      ATTACK: hold LMB (aims BEYOND the monster)      LOOT: SPACE
#
#   1) drops first: after a kill the bot loots before engaging anything else
#   2) drop seeking: coloured light beams are detected and the bot walks ONTO the item,
#      steering by screen quadrant (up-left / up-right / down-left / down-right)
#   3) SPACE is also pressed while fighting, so nothing is left on the ground
#   4) a chase that lasts more than 5 s is abandoned and another target is picked
#   5) the cursor is placed past the monster (player -> monster direction x 60px),
#      which makes the swing connect more reliably
#
#   target policy: only bar-only red HP bars (= wild monsters).
#     * player plates (blue shield / orange stamina, tightly aligned) -> never attacked
#     * named entities (pets / bosses)                                -> never attacked
# Hotkeys: F9 pause/resume, F10 stop.  ESC stop (ESC also opens the game menu).
param(
  [int]$DurationSec = 0,
  [switch]$DryRun,
  [ValidateSet('lmb', 'e')][string]$Engine = 'lmb',
  [double]$AttackRange = 120,
  [int]$Fps = 8,
  [double]$StaminaLow = 0.22,
  [double]$StaminaHigh = 0.55,
  [double]$ChaseLimitSec = 2.0,
  [string]$Goto = '',        # e.g. "100,100": walk to that map coordinate at start
  [switch]$SelfTest,
  [switch]$CoordTest,
  [switch]$TestRespawn,
  [double]$RespawnDownSec = 5.0,
  [string]$ShotDir = '',
  [int]$ShotEvery = 0
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Host "ERROR: PowerShell 5.1 or newer required (this is $($PSVersionTable.PSVersion))"; exit 1 }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# --- engine: HeroBot.cs next to this script, or restored from the embedded copy ---
$csPath = Join-Path $here 'HeroBot.cs'
if (-not (Test-Path $csPath)) {
  Write-Host 'HeroBot.cs not found next to the script - restoring the embedded copy...'
  $blob = @'
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
'@
  try {
    $raw = [Convert]::FromBase64String(($blob -replace '\s',''))
    $ms = New-Object System.IO.MemoryStream(,$raw)
    $gz = New-Object System.IO.Compression.GzipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $sr = New-Object System.IO.StreamReader($gz)
    $src = $sr.ReadToEnd(); $sr.Close()
    [System.IO.File]::WriteAllText($csPath, $src, (New-Object System.Text.UTF8Encoding($false)))
  } catch {
    Write-Host 'ERROR: cannot restore HeroBot.cs:' $_.Exception.Message
    exit 1
  }
}
try { Add-Type -Path $csPath -ReferencedAssemblies System.Drawing -ErrorAction Stop }
catch { Write-Host "ERROR: cannot compile HeroBot.cs (need .NET Framework 4.x / PowerShell 5.1): $($_.Exception.Message)"; exit 1 }
[HB]::Init()

$hwnd = [HB]::FindGameWindow('HerosLand')
if ($hwnd -eq [IntPtr]::Zero) { Write-Host 'ERROR: Hero''s Land not running'; exit 1 }
$sz = [HB]::ClientSize($hwnd); $W = $sz[0]; $H = $sz[1]
$scale = $H / 1080.0
Write-Host "client ${W}x${H} scale=$scale dry=$DryRun engine=$Engine attackR=$AttackRange chaseLimit=$ChaseLimitSec"

$startCursor = [HB]::CursorPos()
$keys = @{ W = $false; A = $false; S = $false; D = $false }
$mouseDown = $false
$autoOn = $false

function SetKey([string]$k, [bool]$want) {
  if ($want -eq $script:keys[$k]) { return }
  $script:lastActionAt = Get-Date
  if (-not $DryRun) { if ($want) { [HB]::KeyDown($k) } else { [HB]::KeyUp($k) } }
  $script:keys[$k] = $want
}
function ReleaseKeys { foreach ($k in @('W', 'A', 'S', 'D')) { SetKey $k $false } }
function SetAuto([bool]$on) {
  if ($on -eq $script:autoOn) { return }
  $script:lastActionAt = Get-Date
  if (-not $DryRun) { [HB]::Tap('E') }
  $script:autoOn = $on
}
function SetMouse([bool]$down) {
  if ($down -eq $script:mouseDown) { return }
  $script:lastActionAt = Get-Date
  if (-not $DryRun) { if ($down) { [HB]::MouseDown() } else { [HB]::MouseUp() } }
  $script:mouseDown = $down
}
function StopAttack { SetAuto $false; SetMouse $false }

# 4-quadrant steering: keys are chosen by which quadrant the target sits in
function MoveQuadrant([double]$tx, [double]$ty, [double]$sx, [double]$sy) {
  $dx = $tx - $sx; $dy = $ty - $sy
  $dead = [math]::Max(9.0, 12.0 * $scale)
  SetKey 'D' ($dx -gt $dead); SetKey 'A' ($dx -lt (-$dead))
  SetKey 'S' ($dy -gt $dead); SetKey 'W' ($dy -lt (-$dead))
}
function QuadrantName([double]$tx, [double]$ty, [double]$sx, [double]$sy) {
  if ($tx -ge $sx -and $ty -lt $sy) { return 'Q1' }   # up-right
  if ($tx -lt $sx -and $ty -lt $sy) { return 'Q2' }   # up-left
  if ($tx -lt $sx -and $ty -ge $sy) { return 'Q3' }   # down-left
  return 'Q4'                                          # down-right
}
function Dist([double]$x1, [double]$y1, [double]$x2, [double]$y2) {
  return [math]::Sqrt(($x1 - $x2) * ($x1 - $x2) + ($y1 - $y2) * ($y1 - $y2))
}

# ---------------- screen coordinate reader (Windows OCR) ----------------
$script:ocrEngine = $null
$script:coordAt = [datetime]::MinValue
$script:coordVal = $null
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
  $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
  $null = [Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime]
  $script:asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
      $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
  $script:ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
} catch { $script:ocrEngine = $null }
if ($null -ne $script:ocrEngine) { Write-Host '[ocr] coordinate reader ready' } else { Write-Host '[ocr] coordinate reader unavailable' }

function Await-WinRT($op, $type) {
  $t = $script:asTask.MakeGenericMethod($type).Invoke($null, @($op))
  $t.Wait(-1) | Out-Null
  return $t.Result
}

# reads the "(x, y)" text next to the minimap; returns @(x,y) or @()
function Get-Coord([bool]$force = $false) {
  if ($null -eq $script:ocrEngine) { return @() }
  $now = Get-Date
  if (-not $force -and ($now - $script:coordAt).TotalMilliseconds -lt 700) { return $script:coordVal }
  $script:coordAt = $now
  try {
    $bmp = [HB]::FrameCopy()
    if ($null -eq $bmp) { [void][HB]::Grab([HB]::FindGameWindow('HerosLand')); $bmp = [HB]::FrameCopy() }
    if ($null -eq $bmp) { return $script:coordVal }
    $w = $bmp.Width; $h = $bmp.Height
    # the coordinate label sits at the bottom-right corner of the minimap
    $rx = [int]($w * 0.850); $ry = [int]($h * 0.140)
    $rw = [int]($w * 0.150); $rh = [int]($h * 0.050)
    $crop = $bmp.Clone((New-Object System.Drawing.Rectangle $rx, $ry, $rw, $rh), $bmp.PixelFormat)
    $bmp.Dispose()
    $scaleUp = 4
    $big = New-Object System.Drawing.Bitmap ($rw * $scaleUp), ($rh * $scaleUp)
    $g = [System.Drawing.Graphics]::FromImage($big)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($crop, 0, 0, $big.Width, $big.Height)
    $g.Dispose(); $crop.Dispose()
    $tmp = Join-Path $env:TEMP 'hb_coord.png'
    $big.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $big.Dispose()

    $file = Await-WinRT ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile])
    $stream = Await-WinRT ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await-WinRT ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $sb = Await-WinRT ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $res = Await-WinRT ($script:ocrEngine.RecognizeAsync($sb)) ([Windows.Media.Ocr.OcrResult])
    $stream.Dispose()

    $txt = [string]$res.Text
    $script:lastOcr = $txt
    if ($env:HB_OCR_DEBUG -eq "1") { Write-Host ("[dbg] ocr text=[{0}] len={1}" -f $txt, $txt.Length) }
    $txt = $txt.ToUpper().Replace('O', '0').Replace('I', '1').Replace('L', '1').Replace('S', '5').Replace('B', '8').Replace('Z', '2').Replace('G', '6')
    # the coordinate line looks like "(115, 101)": two numbers separated by a comma-ish glyph
    $m = [regex]::Match($txt, '(\d{1,3})\s*[^\d\s]{0,2}\s*(\d{1,3})')
    if ($m.Success) {
      $cxv = [int]$m.Groups[1].Value; $cyv = [int]$m.Groups[2].Value
      if ($cxv -le 999 -and $cyv -le 999) { $script:coordVal = @($cxv, $cyv); return $script:coordVal }
    }
    return $script:coordVal
  } catch { $script:lastErr = $_.Exception.Message; return $script:coordVal }
}

# inside the forbidden rectangle (26,29)-(66,52)
function In-AvoidRect([int]$x, [int]$y) {
  return (($x -ge 26) -and ($x -le 66) -and ($y -ge 29) -and ($y -le 52))
}

# press keys until the screen coordinate reaches the waypoint
$script:navQueue = New-Object System.Collections.ArrayList
$script:navTarget = $null
$script:navStuck = 0
$script:navLastCoord = $null

function Nav-Step([double]$sx, [double]$sy) {
  $cur = Get-Coord
  if ($cur.Count -lt 2) { return 'nocoord' }
  $cx = [int]$cur[0]; $cy = [int]$cur[1]
  $tx = [int]$script:navTarget[0]; $ty = [int]$script:navTarget[1]
  if ([math]::Abs($cx - $tx) -le 1 -and [math]::Abs($cy - $ty) -le 1) { return 'arrived' }

  # decide the desired direction in world coordinates
  $wantX = if ($cx -lt $tx) { 1 } elseif ($cx -gt $tx) { -1 } else { 0 }
  $wantY = if ($cy -lt $ty) { 1 } elseif ($cy -gt $ty) { -1 } else { 0 }
  $nx = $cx + $wantX; $ny = $cy + $wantY
  if (In-AvoidRect $nx $ny) {
    # do not step into the forbidden rectangle: move along the free axis first
    if ($wantY -ne 0 -and -not (In-AvoidRect $cx ($cy + $wantY))) { $wantX = 0 }
    elseif ($wantX -ne 0 -and -not (In-AvoidRect ($cx + $wantX) $cy)) { $wantY = 0 }
    else { $wantX = 0; $wantY = 0 }
  }
  # self-correcting signs: if pressing the key moved us the wrong way, flip that axis
  if ($null -ne $script:navLastCoord) {
    $ddx = $cx - $script:navLastCoord[0]; $ddy = $cy - $script:navLastCoord[1]
    if ($wantX -ne 0 -and $ddx -ne 0 -and ([math]::Sign($ddx) -ne [math]::Sign($wantX))) { $script:signX = -$script:signX; Write-Host '[nav] x direction flipped' }
    if ($wantY -ne 0 -and $ddy -ne 0 -and ([math]::Sign($ddy) -ne [math]::Sign($wantY))) { $script:signY = -$script:signY; Write-Host '[nav] y direction flipped' }
  }
  $script:navLastCoord = @($cx, $cy)
  # world -> keys, signs measured during calibration
  $keyX = if ($wantX -gt 0) { if ($script:signX -ge 0) { 'D' } else { 'A' } } elseif ($wantX -lt 0) { if ($script:signX -ge 0) { 'A' } else { 'D' } } else { '' }
  $keyY = if ($wantY -gt 0) { if ($script:signY -ge 0) { 'W' } else { 'S' } } elseif ($wantY -lt 0) { if ($script:signY -ge 0) { 'S' } else { 'W' } } else { '' }
  ReleaseKeys
  if ($keyX) { SetKey $keyX $true }
  if ($keyY) { SetKey $keyY $true }
  return ("moving to ({0},{1}) from ({2},{3})" -f $tx, $ty, $cx, $cy)
}
if (-not $DryRun) {
  [HB]::ForceForeground($hwnd)
  Start-Sleep -Milliseconds 600
  if (-not [HB]::IsForeground($hwnd)) { Write-Host '[warn] the game window is not in the foreground yet - will keep retrying' }
  # calibrate: find out which key increases the on-screen coordinate
  $c0 = Get-Coord $true
  if ($c0.Count -ge 2) {
    [HB]::KeyDown('D'); Start-Sleep -Milliseconds 900; [HB]::KeyUp('D'); Start-Sleep -Milliseconds 350
    $c1 = Get-Coord $true
    [HB]::KeyDown('W'); Start-Sleep -Milliseconds 900; [HB]::KeyUp('W'); Start-Sleep -Milliseconds 350
    $c2 = Get-Coord $true
    if ($c1.Count -ge 2) { if ($c1[0] -ne $c0[0]) { $signX = [math]::Sign($c1[0] - $c0[0]) } }
    if ($c2.Count -ge 2 -and $c1.Count -ge 2) { if ($c2[1] -ne $c1[1]) { $signY = [math]::Sign($c2[1] - $c1[1]) } }
    Write-Host ("[calib] start=({0},{1}) afterD=({2},{3}) afterW=({4},{5})  signX={6} signY={7}" -f $c0[0],$c0[1],$c1[0],$c1[1],$c2[0],$c2[1],$signX,$signY)
  } else { Write-Host ("[calib] coordinate OCR not available - navigation disabled (last OCR: '{0}')" -f $script:lastOcr) }
  if ($Goto -ne '') {
    $parts = $Goto -split ','
    if ($parts.Count -ge 2) {
      $gx = 0; $gy = 0
      if ([int]::TryParse($parts[0].Trim(), [ref]$gx) -and [int]::TryParse($parts[1].Trim(), [ref]$gy)) {
        $navQueue.Clear(); [void]$navQueue.Add(@($gx, $gy)); $navTarget = $null; $navActive = $true
        Write-Host ("[nav] heading to ({0},{1})" -f $gx, $gy)
      }
    }
  }
}

if ($CoordTest) {
  Write-Host "--- coordinate OCR test ---"
  for ($i = 0; $i -lt 5; $i++) {
    $v = Get-Coord $true
    $parsed = if ($v.Count -ge 2) { "($($v[0]),$($v[1]))" } else { "none" }
    Write-Host ("try {0}: raw=[{1}]  parsed={2}  err=[{3}]" -f $i, $script:lastOcr, $parsed, $script:lastErr)
    Start-Sleep -Milliseconds 400
  }
  exit 0
}

$sx = $W / 2.0; $sy = $H / 2.0
$selfSeen = Get-Date
$tgtX = 0.0; $tgtY = 0.0; $tgtAt = [datetime]::MinValue; $hasTgt = $false
$tgtBX0 = 0; $tgtBY0 = 0; $tgtBX1 = 0; $tgtBY1 = 0
$chaseStart = [datetime]::MinValue
$mode = 'hunt'
$wanderKey = 'W'; $wanderUntil = [datetime]::MinValue
$paused = $false; $prevF9 = $false
$fgAt = [datetime]::MinValue; $fgTries = 0
# navigation / respawn recovery
$navActive = $false; $deadSince = [datetime]::MinValue
$navStepAt = [datetime]::MinValue; $baseGoneAt = [datetime]::MinValue; $respawnCooldownUntil = [datetime]::MinValue
$safeExitAt = [datetime]::MinValue
$signX = 1; $signY = -1      # measured by calibration: which key increases the world coordinate
$sw = [Diagnostics.Stopwatch]::StartNew()
$frameMs = [int](1000 / [math]::Max(1, $Fps))
$msgAt = [datetime]::MinValue; $lastLog = ''
$shotIdx = 0; $lastShot = [datetime]::MinValue
$lootPhases = 0; $dmgEvents = 0; $dropTargets = 0; $chests = 0
$hitMaxDist = 0.0        # longest distance at which an attack actually connected (learned)
$zeroSince = [datetime]::MinValue
$prevTgtX = 0.0; $prevTgtY = 0.0; $tgtMoved = $false

$engineNow = $Engine
$staNow = 1.0; $staMin = 1.0
$retreatUntil = [datetime]::MinValue
$restStart = [datetime]::MinValue
$fleeStart = [datetime]::MinValue
$hpIgnoreUntil = [datetime]::MinValue
$lastActionAt = [datetime]::Now
$aimOffsets = @(50, 70, 90, 30)
$aimIdx = 0; $aimAt = [datetime]::MinValue
$fightStart = [datetime]::MinValue; $fightFill = 1.0
$lastFightAt = [datetime]::MinValue

$ignore = @()
$stallD = 1e9; $stallAt = [datetime]::MinValue
$detourUntil = [datetime]::MinValue; $detourSide = 1; $detourX = 0.0; $detourY = 0.0
$motAcc = 0.0; $motN = 0; $motAt = [datetime]::Now; $blockCount = 0

$lootPlan = @(
  @{ K = 'A'; Ms = 240 }, @{ K = 'D'; Ms = 480 }, @{ K = 'W'; Ms = 240 }, @{ K = 'S'; Ms = 480 },
  @{ K = 'A'; Ms = 260 }, @{ K = 'W'; Ms = 260 }, @{ K = 'D'; Ms = 520 }, @{ K = 'S'; Ms = 520 }
)
$lootIdx = 0; $lootPhase = 'idle'; $lootStepAt = [datetime]::MinValue; $lootUntil = [datetime]::MinValue
$handled = @()
$lastSpace = [datetime]::MinValue
$searchUntil = [datetime]::MinValue

if ($SelfTest) {
  Write-Host ''
  Write-Host '--- input self test ---'
  Write-Host ("window handle : {0}" -f $hwnd)
  [HB]::ForceForeground($hwnd)
  Start-Sleep -Milliseconds 700
  $fgOk = [HB]::IsForeground($hwnd)
  Write-Host ("foreground    : {0}" -f $fgOk)
  if (-not $fgOk) {
    Write-Host 'FAIL: cannot focus the game window. Quit exclusive fullscreen and retry.'
    exit 2
  }
  [void][HB]::Grab($hwnd); Start-Sleep -Milliseconds 120; [void][HB]::Grab($hwnd)
  [HB]::KeyDown('W'); Start-Sleep -Milliseconds 1300; [HB]::KeyUp('W')
  Start-Sleep -Milliseconds 200
  [void][HB]::Grab($hwnd)
  $mot = [HB]::LastMotion
  Write-Host ("move test     : background motion {0:N3}  (>0.05 = the character moved)" -f $mot)
  if ($mot -gt 0.05) { Write-Host 'PASS: keyboard reaches the game.' }
  else { Write-Host 'FAIL: character did not move -> input is blocked (UIPI / anti-cheat / wrong window).' }
  $c0 = [HB]::CursorPos()
  [HB]::MoveTo($hwnd, [int]($W / 2), [int]($H / 2))
  Start-Sleep -Milliseconds 250
  $c1 = [HB]::CursorPos()
  Write-Host ("mouse test    : cursor ({0},{1}) -> ({2},{3})" -f $c0[0], $c0[1], $c1[0], $c1[1])
  if (([math]::Abs($c1[0] - $c0[0]) -gt 5) -or ([math]::Abs($c1[1] - $c0[1]) -gt 5)) { Write-Host 'PASS: mouse movement works.' }
  else { Write-Host 'FAIL: mouse did not move.' }
  Write-Host '--- end of self test ---'
  exit 0
}

Write-Host 'running... F9 pause, F10/ESC stop'

while ($true) {
  $iterStart = Get-Date
  if ($DurationSec -gt 0 -and $sw.Elapsed.TotalSeconds -ge $DurationSec) { break }

  $f9 = [HB]::KeyPressed(0x78)
  if ($f9 -and -not $prevF9) { $paused = -not $paused; Write-Host ("[pause] " + $(if ($paused) { 'ON' } else { 'OFF' })) }
  $prevF9 = $f9
  if ([HB]::KeyPressed(0x79) -or [HB]::KeyPressed(0x1B)) { Write-Host '[stop] hotkey'; break }
  if ($paused) { StopAttack; ReleaseKeys; Start-Sleep -Milliseconds 100; continue }
  if (-not $DryRun -and -not [HB]::IsForeground($hwnd)) {
    StopAttack; ReleaseKeys
    $fgTries = [int]$fgTries + 1
    if (($now - $fgAt).TotalSeconds -gt 2.0) {
      [HB]::ForceForeground($hwnd)
      $fgAt = $now
      Write-Host ("[focus] game is not foreground - retry #{0}" -f $fgTries)
      if ($fgTries -eq 4) { Write-Host '[focus] still refused. If the game runs as administrator, start this script as administrator too (Windows blocks synthetic input to elevated windows).' }
    }
    Start-Sleep -Milliseconds 150
    continue
  } else { $fgTries = 0 }

  if (-not [HB]::Grab($hwnd)) { Start-Sleep -Milliseconds 40; continue }
  $sc = [HB]::DetectFrame($scale)
  $now = Get-Date
  $mot = [HB]::LastMotion
  # SPACE is held down in spirit: pick up anything under our feet, whatever we are doing
  if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 300) { [HB]::Tap('SPACE'); $lastSpace = $now }

  # ---------- self / stamina ----------
  if ($null -ne $sc.self) {
    $sx = [double]$sc.self.cx
    $sy = [double]$sc.self.y1 + 52.0 * $scale
    $selfSeen = $now
  } elseif (($now - $selfSeen).TotalSeconds -gt 2.0) {
    $sx = $W / 2.0; $sy = $H / 2.0 + 40 * $scale
  }
  $hp = 1.0; if ($null -ne $sc.self) { $hp = $sc.self.fill }
  if ($null -ne $sc.stamina) { $staNow = $sc.stamina.fill }
  elseif ($null -ne $sc.hudStamina) { $staNow = $sc.hudStamina.fill }
  if ($staNow -lt $staMin) { $staMin = $staNow }

  # ---------- drops: walk onto the beam base ----------
  $nearDrop = $null; $nearDropD = 1e9
  foreach ($d in $sc.drops) {
    $skip = $false
    foreach ($h in $handled) { if ($h.Until -gt $now -and (Dist $d.cx $d.cy $h.X $h.Y) -lt 55) { $skip = $true; break } }
    if ($skip) { continue }
    foreach ($pb in $sc.players) { if ((Dist $d.cx $d.cy $pb.cx $pb.cy) -lt 150 * $scale) { $skip = $true; break } }
    if ($skip) { continue }
    $dd = Dist $d.cx $d.cy $sx $sy
    if ($dd -lt $nearDropD) { $nearDropD = $dd; $nearDrop = $d }
  }


  # ---------- candidate monsters ----------
  $cands = @()
  foreach ($m in $sc.monsters) {
    $mx = [double]$m.cx; $my = [double]$m.y1 + 42.0 * $scale
    if ($mx -lt 60 -or $mx -gt ($W - 60) -or $my -lt 90 -or $my -gt ($H - 140)) { continue }
    if ([HB]::PointInUi([int]$mx, [int]$my, $W, $H)) { continue }
    $skip = $false
    foreach ($ig in $ignore) {
      if ($ig.Until -gt $now -and ([math]::Abs($mx - $ig.X) -lt 70) -and ([math]::Abs($my - $ig.Y) -lt 70)) { $skip = $true; break }
    }
    if ($skip) { continue }
    $cands += [pscustomobject]@{ X = $mx; Y = $my; D = (Dist $mx $my $sx $sy); Fill = $m.fill; Kind = 'monster'; HP = ($m.fill * ($m.x1 - $m.x0 + 1)); BX0 = $m.x0; BY0 = $m.y0; BX1 = $m.x1; BY1 = $m.y1 }
  }
  # a chest is just a monster that does not move: same approach / attack / loot pipeline
  foreach ($ch in $sc.chests) {
    $skip = $false
    foreach ($ig in $ignore) {
      if ($ig.Until -gt $now -and ([math]::Abs($ch.cx - $ig.X) -lt 70) -and ([math]::Abs($ch.cy - $ig.Y) -lt 70)) { $skip = $true; break }
    }
    if ($skip) { continue }
    $cd = Dist $ch.cx $ch.cy $sx $sy
    if ($cd -gt 900) { continue }
    $cands += [pscustomobject]@{ X = [double]$ch.cx; Y = [double]$ch.cy; D = $cd; Fill = 1.0; Kind = 'chest'; HP = (0.5 * ($ch.x1 - $ch.x0 + 1)); BX0 = $ch.x0 - 12; BY0 = $ch.y0 - 75; BX1 = $ch.x1 + 12; BY1 = $ch.y0 - 4 }
  }

  # ---------- target selection ----------
  # priority: the monster with the least ABSOLUTE remaining HP (red bar length = fill x width),
  # but only targets within 700px. The current target keeps a little hysteresis so the bot
  # does not flip-flop between two equally hurt monsters.
  $chosen = $null
  $bestHp = 1e9
  foreach ($c in $cands) {
    if ($c.D -gt 700) { continue }
    if ($c.HP -lt $bestHp) { $bestHp = $c.HP; $chosen = $c }
  }
  if ($null -ne $chosen -and $hasTgt) {
    foreach ($c in $cands) {
      if ((Dist $c.X $c.Y $tgtX $tgtY) -lt 90 -and $c.HP -le $bestHp * 1.25) { $chosen = $c; $bestHp = $c.HP; break }
    }
  }
  if ($null -eq $chosen) {
    $min = 1e9
    foreach ($c in $cands) { if ($c.D -lt $min) { $min = $c.D; $chosen = $c } }
  }
  if ($null -ne $chosen) { $tgtBX0 = $chosen.BX0; $tgtBY0 = $chosen.BY0; $tgtBX1 = $chosen.BX1; $tgtBY1 = $chosen.BY1 }
  if ($lootPhase -ne 'idle' -and $now -lt $lootUntil -and $hp -ge 0.45) { $chosen = $null }

  # effective attack distance: start with the nominal range, tighten it once we have measured a hit
  if ($null -ne $chosen) {
    $tgtMoved = ((Dist $chosen.X $chosen.Y $prevTgtX $prevTgtY) -gt 6.0 * $scale)
    $prevTgtX = $chosen.X; $prevTgtY = $chosen.Y
  }
  $effRange = $AttackRange
  if ($hitMaxDist -gt 40) { $effRange = [math]::Max(80, [math]::Min($AttackRange, $hitMaxDist * 1.05)) }

  # ---------- safe zone (portal): no attacking inside, but looting + healing works ----------
  $inSafe = $false; $portalX = 0.0; $portalY = 0.0; $portalR = 0.0
  if ($null -ne $sc.portal) {
    $portalX = [double]$sc.portal.cx; $portalY = [double]$sc.portal.cy; $portalR = [double]$sc.portal.r
    $inSafe = ((Dist $portalX $portalY $sx $sy) -lt ($portalR * 1.35 + 40))
  }

  # ---------- death / respawn ----------
  # the SPIN wheel only exists on the respawn screen -> that is our "you died" signal
  $respawnScene = $false
  try { $respawnScene = [HB]::IsRespawnScene() } catch { $respawnScene = $false }
  if (($respawnScene -or $TestRespawn) -and $now -ge $respawnCooldownUntil) {
    if ($deadSince -eq [datetime]::MinValue) { $deadSince = $now }
    elseif (-not $navActive -and ($now - $deadSince).TotalSeconds -gt 1.0) {
      Write-Host ("[respawn] respawn screen detected - leaving the base: straight down for {0}s" -f $RespawnDownSec)
      $navQueue.Clear(); [void]$navQueue.Add(@(0, -1))   # 0,-1 = "walk down" marker
      $navTarget = $null; $navActive = $true; $navStuck = 0
      $deadSince = $now.AddHours(1)
    }
  } else {
    $deadSince = [datetime]::MinValue
  }

  # ---------- state machine ----------
  # ---------- state machine ----------
  if ($hp -lt 0.28 -and $now -ge $hpIgnoreUntil) {
    $mode = 'flee'; StopAttack; ReleaseKeys
    if ($fleeStart -eq [datetime]::MinValue) { $fleeStart = $now }
    if (($now - $fleeStart).TotalSeconds -gt 6.0) { $hpIgnoreUntil = $now.AddSeconds(6.0); $fleeStart = [datetime]::MinValue }
    $lastActionAt = $now
    if ($hasTgt) {
      $dx = $sx - $tgtX; $dy = $sy - $tgtY
      SetKey 'D' ($dx -gt 10); SetKey 'A' ($dx -lt -10)
      SetKey 'S' ($dy -gt 10); SetKey 'W' ($dy -lt -10)
    }
  }
  elseif ($now -lt $retreatUntil) {
    $mode = 'rest'; StopAttack
    if ($restStart -eq [datetime]::MinValue) { $restStart = $now }
    if ($staNow -ge $StaminaHigh -or ($now - $restStart).TotalSeconds -gt 6.0) { $retreatUntil = [datetime]::MinValue; $restStart = [datetime]::MinValue }
    $lastActionAt = $now
    if ($hasTgt) {
      $dx = $sx - $tgtX; $dy = $sy - $tgtY
      SetKey 'D' ($dx -gt 10); SetKey 'A' ($dx -lt -10)
      SetKey 'S' ($dy -gt 10); SetKey 'W' ($dy -lt -10)
    } else { ReleaseKeys }
    if ($staNow -ge $StaminaHigh) { $retreatUntil = [datetime]::MinValue
$restStart = [datetime]::MinValue
$fleeStart = [datetime]::MinValue
$hpIgnoreUntil = [datetime]::MinValue
$lastActionAt = [datetime]::Now }
  }
  elseif ($staNow -lt $StaminaLow -and $null -ne $chosen) {
    $mode = 'rest'; $retreatUntil = $now.AddSeconds(2.5); $restStart = $now; StopAttack
    Write-Host ("[stamina] low {0:N2} -> rest" -f $staNow)
  }
  elseif ($navActive) {
    $mode = 'respawn'; StopAttack
    if ($null -eq $navTarget) {
      if ($navQueue.Count -gt 0) { $navTarget = $navQueue[0]; $navQueue.RemoveAt(0); $navStuck = 0; $navStepAt = $now }
      else { $navActive = $false }
    }
    if ($navActive) {
      if ($navTarget[0] -eq 0 -and $navTarget[1] -eq -1) {
        # timed walk straight "down" (screen S) to leave the respawn base
        SetKey 'W' $false; SetKey 'A' $false; SetKey 'D' $false; SetKey 'S' $true
        # stop once the SPIN base is out of view (with a margin), plus a hard cap
        if (-not $respawnScene) { if ($baseGoneAt -eq [datetime]::MinValue) { $baseGoneAt = $now } }
        else { $baseGoneAt = [datetime]::MinValue }
        $gone = $false
        if ($baseGoneAt -ne [datetime]::MinValue) { $gone = (($now - $baseGoneAt).TotalSeconds -gt 0.5) }
        $cap  = (($now - $navStepAt).TotalSeconds -gt ($RespawnDownSec * 3))
        if ($gone -or $cap) {
          ReleaseKeys; $navActive = $false; $navTarget = $null
          $deadSince = [datetime]::MinValue; $baseGoneAt = [datetime]::MinValue
          $respawnCooldownUntil = $now.AddSeconds(30)
          Write-Host '[respawn] left the base - back to farming'
        }
      } else {
        $r = Nav-Step $sx $sy
        if ($r -eq 'arrived') {
          Write-Host ("[nav] arrived at ({0},{1})" -f $navTarget[0], $navTarget[1])
          $navTarget = $null
          if ($navQueue.Count -eq 0) { $navActive = $false; ReleaseKeys; Write-Host '[nav] route finished' }
        } elseif ($r -eq 'nocoord') {
          MoveQuadrant $sx ($sy + 220) $sx $sy
          $navStuck++
          if ($navStuck -gt 40) { Write-Host '[nav] cannot read coordinates - aborting route'; $navActive = $false; ReleaseKeys }
        }
      }
    }
  }
  elseif ($inSafe) {
    # inside the portal: attacks do nothing, so loot and heal, then leave deliberately
    $mode = 'safe'; StopAttack
    if ($null -ne $nearDrop -and $nearDropD -lt 420) {
      if ($nearDropD -gt 45) { MoveQuadrant $nearDrop.cx $nearDrop.cy $sx $sy } else { ReleaseKeys }
    } elseif ($hp -lt 0.92) {
      ReleaseKeys                     # stand still and regenerate
    } else {
      # leave the safe zone in a straight line (S). Random "away from the portal" steering
      # made the bot circle inside the base - this is deterministic instead.
      SetKey 'W' $false; SetKey 'A' $false; SetKey 'D' $false; SetKey 'S' $true
      if ($safeExitAt -eq [datetime]::MinValue) { $safeExitAt = $now }
      if (($now - $safeExitAt).TotalSeconds -gt 25) { ReleaseKeys; $safeExitAt = [datetime]::MinValue }
    }
  }
  elseif ($null -ne $sc.portal -and $hp -lt 0.45 -and -not $inSafe) {
    # hurt: run into the portal to heal
    $mode = 'toSafe'; StopAttack
    MoveQuadrant $portalX $portalY $sx $sy
  }
  elseif (($lootPhase -ne 'idle' -and $now -lt $lootUntil) -or ($null -ne $nearDrop -and $nearDropD -lt 450 -and -not ($null -ne $chosen -and $chosen.D -le $effRange))) {
    # ---- loot has priority over new monsters, but keep swinging at anything in reach ----
    $mode = 'loot'
    $closeMon = $null; $closeD = 1e9
    foreach ($cc in $cands) { if ($cc.D -lt $closeD) { $closeD = $cc.D; $closeMon = $cc } }
    if ($null -ne $closeMon -and $closeD -lt 230 -and $engineNow -eq 'lmb') {
      if (-not $DryRun) { [HB]::MoveTo($hwnd, [int]$closeMon.X, [int]($closeMon.Y + 55 * $scale)) }
      SetMouse $true
    } else { StopAttack }
    if ($null -ne $nearDrop -and $nearDropD -lt 500) {
      $dropTargets++
      if ($nearDropD -gt 42) {
        MoveQuadrant $nearDrop.cx $nearDrop.cy $sx $sy
        if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 260) { [HB]::Tap('SPACE'); $lastSpace = $now }
      } else {
        ReleaseKeys
        if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 170) { [HB]::Tap('SPACE'); $lastSpace = $now }
        if (($now - $lootStepAt).TotalMilliseconds -gt 700) {
          $handled += [pscustomobject]@{ X = $nearDrop.cx; Y = $nearDrop.cy; Until = $now.AddSeconds(4) }
          $lootStepAt = $now
        }
      }
    } else {
      $step = $lootPlan[$lootIdx]
      if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 190) { [HB]::Tap('SPACE'); $lastSpace = $now }
      if ($lootPhase -eq 'move') {
        SetKey $step.K $true
        if (($now - $lootStepAt).TotalMilliseconds -ge $step.Ms) { ReleaseKeys; $lootPhase = 'tap'; $lootStepAt = $now }
      } else {
        ReleaseKeys
        if (($now - $lootStepAt).TotalMilliseconds -ge 560) {
          $lootIdx++
          if ($lootIdx -ge $lootPlan.Count) { $lootPhase = 'idle' } else { $lootPhase = 'move'; $lootStepAt = $now }
        }
      }
    }
  }

  elseif ($null -ne $chosen -and $chosen.D -gt 230) {
    # ---- far target: run at it (give up after ChaseLimitSec) ----
    $mode = 'chase'; $hasTgt = $true
    $tgtX = $chosen.X; $tgtY = $chosen.Y; $tgtAt = $now
    if (($now - $chaseStart).TotalSeconds -gt $ChaseLimitSec -and $chaseStart -ne [datetime]::MinValue) {
      $ignore += [pscustomobject]@{ X = $chosen.X; Y = $chosen.Y; Until = $now.AddSeconds(10) }
      Write-Host ("[chase] gave up after {0:N1}s at d={1}" -f $ChaseLimitSec, [int]$chosen.D)
      $hasTgt = $false; StopAttack; $chaseStart = [datetime]::MinValue
    } else {
      if ($chaseStart -eq [datetime]::MinValue) { $chaseStart = $now }
      StopAttack
      if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 600) { [HB]::Tap('SPACE'); $lastSpace = $now }
      if ($now -lt $detourUntil) {
        MoveQuadrant $detourX $detourY $sx $sy
      } else {
        MoveQuadrant $chosen.X $chosen.Y $sx $sy
        if ($chosen.D -lt ($stallD - 8)) { $stallD = $chosen.D; $stallAt = $now }
        elseif (($now - $stallAt).TotalSeconds -gt 1.2 -and $mot -lt 0.06) {
          $detourSide = -$detourSide
          $vx = $chosen.X - $sx; $vy = $chosen.Y - $sy
          $L = [math]::Sqrt($vx * $vx + $vy * $vy); if ($L -lt 1) { $L = 1 }
          $detourX = $sx + (-$vy / $L) * $detourSide * 150
          $detourY = $sy + ($vx / $L) * $detourSide * 150
          $detourUntil = $now.AddMilliseconds(950)
          $stallD = $chosen.D; $stallAt = $now
          Write-Host ("[avoid] blocked at d={0} -> sidestep" -f [int]$chosen.D)
        }
      }
    }
  }
  elseif ($null -ne $chosen) {
    # ---- in front of us: HOLD the button and keep swinging until it disappears ----
    $mode = 'fight'; $hasTgt = $true; $chaseStart = [datetime]::MinValue
    $tgtX = $chosen.X; $tgtY = $chosen.Y; $tgtAt = $now
    if (($now - $lastFightAt).TotalSeconds -gt 1.5) { $fightStart = $now; $fightFill = $chosen.Fill; $aimAt = $now }
    $lastFightAt = $now
    # walk in while already swinging (never release)
    if ($chosen.D -gt $AttackRange) { MoveQuadrant $chosen.X $chosen.Y $sx $sy } else { ReleaseKeys }
    if ($engineNow -eq 'e') {
      SetAuto $true
    } else {
      $vx = $chosen.X - $sx; $vy = ($chosen.Y + 50 * $scale) - $sy
      $L = [math]::Sqrt($vx * $vx + $vy * $vy); if ($L -lt 1) { $L = 1 }
      if ($chosen.Kind -eq 'chest') {
        $ax = [int]$chosen.X
        $ay = [int]($chosen.Y + 8 * $scale)
      } elseif ($tgtMoved) {
        $ax = [int]$chosen.X
        $ay = [int]($chosen.Y + 55 * $scale)
      } else {
        $reach = 55 + $aimOffsets[$aimIdx]
        $ax = [int]($chosen.X + $vx / $L * $reach * $scale)
        $ay = [int]($chosen.Y + 50 * $scale + $vy / $L * $reach * $scale)
      }
      if (-not $DryRun) { [HB]::MoveTo($hwnd, $ax, $ay) }
      SetMouse $true          # stays pressed: no release, no re-click
    }
    # SPACE also while fighting: loot is picked up under our feet
    if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 600) { [HB]::Tap('SPACE'); $lastSpace = $now }
    if ($chosen.Kind -ne 'chest') {
      if ($chosen.Fill -lt ($fightFill - 0.004)) {
        $fightFill = $chosen.Fill; $aimAt = $now; $dmgEvents++
        if ($chosen.D -gt $hitMaxDist) { $hitMaxDist = $chosen.D; Write-Host ("[range] hit confirmed at d={0}" -f [int]$chosen.D) }
      } elseif (($now - $aimAt).TotalSeconds -gt 1.5) {
        # only slide the aim point, never let go of the button
        $aimIdx = ($aimIdx + 1) % $aimOffsets.Count
        $aimAt = $now
      }
    }
    if ($chosen.Kind -ne 'chest' -and $chosen.Fill -le 0.001) {
      if ($zeroSince -eq [datetime]::MinValue) { $zeroSince = $now }
      elseif (($now - $zeroSince).TotalSeconds -gt 6.0) {
        $ignore += [pscustomobject]@{ X = $chosen.X; Y = $chosen.Y; Until = $now.AddSeconds(10) }
        Write-Host ("[target] empty bar for 6s at ({0},{1}) -> corpse, skip" -f [int]$chosen.X, [int]$chosen.Y)
        $hasTgt = $false; StopAttack; $mode = 'hunt'; $zeroSince = [datetime]::MinValue
      }
    } else { $zeroSince = [datetime]::MinValue }
    if ($chosen.Kind -eq 'chest' -and ($now - $fightStart).TotalSeconds -gt 5.0) {
      # a chest breaks after two hits; still here after 5 s = false positive
      $ignore += [pscustomobject]@{ X = $chosen.X; Y = $chosen.Y; Until = $now.AddSeconds(12) }
      Write-Host ("[chest] still present after 5s at ({0},{1}) -> skip" -f [int]$chosen.X, [int]$chosen.Y)
      $hasTgt = $false; StopAttack; $mode = 'hunt'
    }
  }
  else {
    # ---------- no monster visible ----------
    $lostFor = 999.0
    if ($hasTgt) { $lostFor = ($now - $tgtAt).TotalSeconds }
    $wasFighting = (($now - $lastFightAt).TotalSeconds -lt 4.0)

    $barStill = $false
    if ($hasTgt -and $tgtBX1 -gt $tgtBX0) { $barStill = [HB]::DarkStripAt([int]$tgtBX0, [int]$tgtBY0, [int]$tgtBX1, [int]$tgtBY1) }
    if ($hasTgt -and (($lostFor -lt 0.9 -and $mode -eq 'fight') -or ($barStill -and $lostFor -lt 3.0))) {
      # bar flickered for a frame or two: keep swinging at the same spot
      $mode = 'hold'; ReleaseKeys
      if ($engineNow -eq 'lmb' -and -not $DryRun) {
        $vx = $tgtX - $sx; $vy = ($tgtY + 50 * $scale) - $sy
        $L = [math]::Sqrt($vx * $vx + $vy * $vy); if ($L -lt 1) { $L = 1 }
        [HB]::MoveTo($hwnd, [int]($tgtX + $vx / $L * 60 * $scale), [int]($tgtY + 50 * $scale + $vy / $L * 60 * $scale))
      }
      SetMouse $true
      # step toward the last known spot so a moved monster is re-acquired instead of standing still
      MoveQuadrant $tgtX $tgtY $sx $sy
    }
    else {
      if ($hasTgt) {
        if ($wasFighting) {
          $lootPhase = 'move'; $lootIdx = 0; $lootStepAt = $now
          $lootUntil = $now.AddSeconds(8.0); $lootPhases++
          Write-Host '[loot] kill confirmed -> collect drops'
        } elseif ($lostFor -lt 2.5) {
          $searchUntil = $now.AddSeconds(2.5)
        }
        $hasTgt = $false
      }
      if ($lootPhase -ne 'idle' -and $now -lt $lootUntil) {
        $mode = 'loot'; StopAttack
        $step = $lootPlan[$lootIdx]
        if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 190) { [HB]::Tap('SPACE'); $lastSpace = $now }
        if ($lootPhase -eq 'move') {
          SetKey $step.K $true
          if (($now - $lootStepAt).TotalMilliseconds -ge $step.Ms) { ReleaseKeys; $lootPhase = 'tap'; $lootStepAt = $now }
        } else {
          ReleaseKeys
          if (($now - $lootStepAt).TotalMilliseconds -ge 560) {
            $lootIdx++
            if ($lootIdx -ge $lootPlan.Count) { $lootPhase = 'idle' } else { $lootPhase = 'move'; $lootStepAt = $now }
          }
        }
      }
      elseif ($now -lt $searchUntil) {
        $mode = 'search'; StopAttack
        MoveQuadrant $tgtX $tgtY $sx $sy
        if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 400) { [HB]::Tap('SPACE'); $lastSpace = $now }
      }
      else {
        $mode = 'hunt'; StopAttack
        if ($now -gt $wanderUntil) {
          $idx = @('W', 'A', 'S', 'D').IndexOf($wanderKey); if ($idx -lt 0) { $idx = 0 }
          $wanderKey = @('W', 'A', 'S', 'D')[($idx + 1) % 4]
          $wanderUntil = $now.AddMilliseconds(6500)
        }
        ReleaseKeys; SetKey $wanderKey $true
        if (-not $DryRun) {
          $motAcc += $mot; $motN++
          if (($now - $motAt).TotalSeconds -gt 0.8) {
            $avg = $motAcc / [math]::Max(1, $motN)
            if ($avg -lt 0.055) {
              $blockCount++
              $opp = @{ W = 'S'; S = 'W'; A = 'D'; D = 'A' }[$wanderKey]
              ReleaseKeys; SetKey $opp $true
              Start-Sleep -Milliseconds ($(if ($blockCount -ge 3) { 900 } else { 450 }))
              SetKey $opp $false
              $idx = @('W', 'A', 'S', 'D').IndexOf($wanderKey); if ($idx -lt 0) { $idx = 0 }
              $wanderKey = @('W', 'A', 'S', 'D')[($idx + 1) % 4]
              $wanderUntil = $now.AddMilliseconds(1800)
              ReleaseKeys; SetKey $wanderKey $true
              Write-Host ("[avoid] blocked (motion {0:N3}) -> back off + turn {1}" -f $avg, $wanderKey)
            } elseif ($avg -gt 0.08) { $blockCount = 0 }
            $motAcc = 0.0; $motN = 0; $motAt = $now
          }
        }
        if (-not $DryRun -and ($now - $lastSpace).TotalMilliseconds -gt 500) { [HB]::Tap('SPACE'); $lastSpace = $now }
      }
    }
  }

  # ---------- log ----------
  if (($now - $msgAt).TotalSeconds -ge 1.0) {
    $msgAt = $now
    $ignore = @($ignore | Where-Object { $_.Until -gt $now })
    $handled = @($handled | Where-Object { $_.Until -gt $now })
    $t = if ($null -ne $chosen) { "($([int]$chosen.X),$([int]$chosen.Y)) d=$([int]$chosen.D) f=$([math]::Round($chosen.Fill,2)) hp=$([int]$chosen.HP)" } else { '-' }
    $chestInfo = if ($null -ne $chosen -and $chosen.Kind -eq 'chest') { "chest@($([int]$chosen.X),$([int]$chosen.Y)) d=$([int]$chosen.D)" } else { '-' }
    $dp = if ($null -ne $nearDrop) { "beam($([int]$nearDrop.cx),$([int]$nearDrop.cy)) d=$([int]$nearDropD) $(QuadrantName $nearDrop.cx $nearDrop.cy $sx $sy)" } else { '-' }
    $line = "[{0,5:N1}s] {1,-6} self=({2},{3}) hp={4:N2} sta={5:N2} tgt={6} n={7} ply={8} drop={9} loot={10} {11}" -f `
      $sw.Elapsed.TotalSeconds, $mode, [int]$sx, [int]$sy, $hp, $staNow, $t, $cands.Count, $sc.players.Count, $dp, $lootPhase, $chestInfo
    if ($line -ne $lastLog) { Write-Host $line; $lastLog = $line }
  }

  if ($ShotDir -ne '' -and $ShotEvery -gt 0 -and ($now - $lastShot).TotalSeconds -ge $ShotEvery) {
    $lastShot = $now; $shotIdx++
    $cp = [HB]::FrameCopy()
    [HB]::Annotate($cp, $sc, (Join-Path $ShotDir ("bot_{0:D3}.png" -f $shotIdx)))
    $cp.Dispose()
  }

  # anti-idle watchdog: if no input has been produced for 2 s, force a hunt move
  if (-not $DryRun -and $mode -ne 'rest' -and $mode -ne 'flee' -and $mode -ne 'respawn' -and $mode -ne 'nav' -and ($now - $lastActionAt).TotalSeconds -gt 2.0) {
    StopAttack; ReleaseKeys
    $wanderKey = @('W', 'A', 'S', 'D')[(Get-Random -Maximum 4)]
    SetKey $wanderKey $true
    $wanderUntil = $now.AddMilliseconds(1200)
    $lastActionAt = $now
    Write-Host '[idle] watchdog -> force move'
  }

  $elapsed = [int]((Get-Date) - $iterStart).TotalMilliseconds
  if ($elapsed -lt $frameMs) { Start-Sleep -Milliseconds ($frameMs - $elapsed) }
}

StopAttack; ReleaseKeys
if (-not $DryRun) { try { [HB]::SetCursorPos($startCursor[0], $startCursor[1]) } catch { } }
Write-Host ("done {0}s  loot-phases={1} stamina-min={2:N2} damage-events={3} drop-chases={4} chests={5}" -f [int]$sw.Elapsed.TotalSeconds, $lootPhases, $staMin, $dmgEvents, $dropTargets, $chests)
















