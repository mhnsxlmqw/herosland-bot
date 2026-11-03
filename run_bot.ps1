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
















