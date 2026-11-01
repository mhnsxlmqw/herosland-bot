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
  [double]$ChaseLimitSec = 5.0,
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

if (-not $DryRun) { [void][HB]::Focus($hwnd); Start-Sleep -Milliseconds 500 }

$sx = $W / 2.0; $sy = $H / 2.0
$selfSeen = Get-Date
$tgtX = 0.0; $tgtY = 0.0; $tgtAt = [datetime]::MinValue; $hasTgt = $false
$tgtBX0 = 0; $tgtBY0 = 0; $tgtBX1 = 0; $tgtBY1 = 0
$chaseStart = [datetime]::MinValue
$mode = 'hunt'
$wanderKey = 'W'; $wanderUntil = [datetime]::MinValue
$paused = $false; $prevF9 = $false
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

Write-Host 'running... F9 pause, F10/ESC stop'

while ($true) {
  $iterStart = Get-Date
  if ($DurationSec -gt 0 -and $sw.Elapsed.TotalSeconds -ge $DurationSec) { break }

  $f9 = [HB]::KeyPressed(0x78)
  if ($f9 -and -not $prevF9) { $paused = -not $paused; Write-Host ("[pause] " + $(if ($paused) { 'ON' } else { 'OFF' })) }
  $prevF9 = $f9
  if ([HB]::KeyPressed(0x79) -or [HB]::KeyPressed(0x1B)) { Write-Host '[stop] hotkey'; break }
  if ($paused) { StopAttack; ReleaseKeys; Start-Sleep -Milliseconds 100; continue }
  if (-not $DryRun -and -not [HB]::IsForeground($hwnd)) { StopAttack; ReleaseKeys; Start-Sleep -Milliseconds 150; continue }

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
    $cands += [pscustomobject]@{ X = $mx; Y = $my; D = (Dist $mx $my $sx $sy); Fill = $m.fill; Kind = 'monster'; BX0 = $m.x0; BY0 = $m.y0; BX1 = $m.x1; BY1 = $m.y1 }
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
    $cands += [pscustomobject]@{ X = [double]$ch.cx; Y = [double]$ch.cy; D = $cd; Fill = 1.0; Kind = 'chest'; BX0 = $ch.x0 - 12; BY0 = $ch.y0 - 75; BX1 = $ch.x1 + 12; BY1 = $ch.y0 - 4 }
  }

  # ---------- target lock ----------
  $chosen = $null
  if ($hasTgt) {
    $best = 1e9
    foreach ($c in $cands) {
      $dd = Dist $c.X $c.Y $tgtX $tgtY
      if ($dd -lt 260 -and $dd -lt $best) { $best = $dd; $chosen = $c }
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
    $t = if ($null -ne $chosen) { "($([int]$chosen.X),$([int]$chosen.Y)) d=$([int]$chosen.D) f=$([math]::Round($chosen.Fill,2))" } else { '-' }
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
















