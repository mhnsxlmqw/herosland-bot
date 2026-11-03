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
  # water blocks attacks and drains stamina: never walk into it, sidestep instead
  if (-not $DryRun) {
    $len = [math]::Sqrt($dx * $dx + $dy * $dy)
    if ($len -gt 20) {
      $probeX = [int]($sx + $dx / $len * 85)
      $probeY = [int]($sy + $dy / $len * 85)
      if ([HB]::WaterAt($probeX, $probeY) -gt 0.55) {
        switch ([HB]::WaterEscapeDir([int]$sx, [int]$sy, 110)) {
          0 { $tx = $sx; $ty = $sy - 100 }
          1 { $tx = $sx + 100; $ty = $sy }
          2 { $tx = $sx; $ty = $sy + 100 }
          3 { $tx = $sx - 100; $ty = $sy }
        }
        $dx = $tx - $sx; $dy = $ty - $sy
      }
    }
  }
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
  # harvestable resources: only worth attacking when nothing better is around
  foreach ($rr in $sc.resources) {
    $skip = $false
    foreach ($ig in $ignore) {
      if ($ig.Until -gt $now -and ([math]::Abs($rr.cx - $ig.X) -lt 70) -and ([math]::Abs(($rr.cy + 40) - $ig.Y) -lt 90)) { $skip = $true; break }
    }
    if ($skip) { continue }
    $rd = Dist $rr.cx ($rr.cy + 40) $sx $sy
    if ($rd -gt 480) { continue }
    $cands += [pscustomobject]@{ X = [double]$rr.cx; Y = [double]($rr.cy + 40); D = $rd; Fill = 1.0; Kind = 'resource'; HP = 900; BX0 = $rr.x0 - 10; BY0 = $rr.y0 - 10; BX1 = $rr.x1 + 10; BY1 = $rr.cy + 10 }
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

  # ---------- water ----------
  $onWater = $false
  if (-not $DryRun) { $onWater = ([HB]::WaterAt([int]$sx, [int]$sy) -gt 0.55) }

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
  elseif ($onWater) {
    # standing in water: no attacking, stamina draining - get out first
    $mode = 'water'; StopAttack
    switch ([HB]::WaterEscapeDir([int]$sx, [int]$sy, 120)) {
      0 { SetKey 'S' $false; SetKey 'W' $true; SetKey 'A' $false; SetKey 'D' $false }
      1 { SetKey 'W' $false; SetKey 'S' $false; SetKey 'A' $false; SetKey 'D' $true }
      2 { SetKey 'W' $false; SetKey 'S' $true; SetKey 'A' $false; SetKey 'D' $false }
      3 { SetKey 'W' $false; SetKey 'S' $false; SetKey 'D' $false; SetKey 'A' $true }
    }
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
















