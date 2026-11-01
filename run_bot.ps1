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
  [switch]$SelfTest,
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

if (-not $DryRun) {
  [HB]::ForceForeground($hwnd)
  Start-Sleep -Milliseconds 600
  if (-not [HB]::IsForeground($hwnd)) { Write-Host '[warn] the game window is not in the foreground yet - will keep retrying' }
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
  elseif ($inSafe) {
    # inside the portal: attacks do nothing, so loot and heal, then walk out
    $mode = 'safe'; StopAttack
    if ($null -ne $nearDrop -and $nearDropD -lt 420) {
      if ($nearDropD -gt 45) { MoveQuadrant $nearDrop.cx $nearDrop.cy $sx $sy } else { ReleaseKeys }
    } elseif ($hp -lt 0.92) {
      ReleaseKeys                     # stand still and regenerate
    } else {
      # healthy and nothing to pick up: leave the safe zone
      $dx = $sx - $portalX; $dy = $sy - $portalY
      if ([math]::Abs($dx) -lt 1 -and [math]::Abs($dy) -lt 1) { $dx = 1 }
      MoveQuadrant ($sx + $dx) ($sy + $dy) $sx $sy
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
  if (-not $DryRun -and $mode -ne 'rest' -and $mode -ne 'flee' -and ($now - $lastActionAt).TotalSeconds -gt 2.0) {
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
















