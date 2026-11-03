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
0AXb799U/vt/DW45FFTHAAA=
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
$dlgAt = [datetime]::MinValue; $dlgCooldownUntil = [datetime]::MinValue
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

  # ---------- teleport dialog ----------
  $dlg = $null
  if (-not $DryRun -and $now -ge $dlgCooldownUntil) { try { $dlg = [HB]::FindTeleportDialog() } catch { $dlg = $null } }

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
  if ($null -ne $dlg) {
    # accidentally stepped on a portal: close the destination picker
    $mode = 'dialog'; StopAttack; ReleaseKeys
    if ($now -ge $dlgAt) {
      [HB]::ClientClick($hwnd, [int]$dlg[1], [int]$dlg[2])
      Write-Host ("[dialog] teleport picker detected - clicked close at ({0},{1})" -f $dlg[1], $dlg[2])
      $dlgAt = $now.AddMilliseconds(900)
      $dlgCooldownUntil = $now.AddSeconds(2.5)
    }
  }
  elseif ($hp -lt 0.28 -and $now -ge $hpIgnoreUntil) {
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
















$dlgAt = [datetime]::MinValue; $dlgCooldownUntil = [datetime]::MinValue
