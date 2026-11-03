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
H4sIAAAAAAAEAN19a3PbuLLg96na/4B4a8+RYlnWw/Y4ceIpvzJ2jWN7LWc8Wa/LRZGUxDJF6pBUJM7j/vbtbgAkQIKUnEzOubWaqZgEgQbY6G50NxrN7W12
7kbhcZi07ZhtbdHdP2N2aQUO++LFXhiwTeYFs3nC3GDsBe4P29vseO75zlt2Ey7caDBxfZ+xI8fZuktnLtu6sZIJa/9fFeytO3IjN7Bd5yiO3enQ99yYDdI4
caft08haeMEYwd5Z0dhN3rL21dkd+xBZU3cRRs9sp71k2+zkf7LdH+YxVBUtD7S79kno+66dwIDj9s9u4EaeXaghejKXti+m1rj89HYeJN7UbV8ECbzPbOBG
XzzbjQ9++GE2h9ewWZxYCfyxfSuO2fnxD3/8wOAHL7NV+LF7L+j3SsVU/WGQRHM7ubTScJ40+J9fvMBpD9x/zV0YgeU3H6lm1ivWZ7dnJ3fsD1noBQm7bLG7
FrttseMD9tcP3wT85vriqgD9txb7nMM99f2L6SyMksbGPHajfq/t+P5G85HpqHGXgLqADcPQZz+7yQlMfpDcwlQ1AKk3ScQmLQZD4i8TNQ++GjiHfBcO7Mh1
AwV65I7E28y+AfxNBCiASXTChQJbXjl2i80RR6Ov60LAAQR9CCN3HIXzwBGdfcOYBwZwcsTfAnYSLkqYwJe3vw5oPIGa+O5HcRrYv7jpAB67DYT45fkbxonk
No/iMLoJ4wbS2LdTwUAFiQNc8jdPvw4mkczADZwLFLENug2Aqq5uPt09QBuB1uG3jfgmCkFoxac3F0cLK3K/kqJwJIBRLhk/uglIWI4C7xtGdxFzQvoV1pqh
7/4d1HkRX9hh4NkqrG+ShDQbuSSkSUpgrTuQJTR5nwJcLD+tlrtnyxk08hJzXxkoesiXEwL3wXN953o0it2k0ckR8PH60+CMj3DqHays/svZ5+NTXv15jern
R7en90e3ooOJaPGNK4syZG15cZYH2m16oKF8GgIFnFqJpRc7iw++NY71Qly0lekhOnAWZ8sksi6CUfjNi6OCxpwuuBhb/Pp8UCwa2Fbw32DU+mzqBD3/GI9L
476xQAu7NBefZ8MBbosTDoUgP9EEs/esIyTZE6LrGjqHsu5BsQ08PPv17Oruw9Pg5Ojq5PqUmi47nc5+S3kIV59u5JNeCQr1Kap+vP41g9FtaY+OjgfXl5/u
+ON9eF4L6PLsw93p9f1V1m2r9Dgf044QM7pk4iIp8BLXgYojy49dY70voedQvUazwPneiDU4gCaoMsk8CnK+TaIU5tEo4tlfzLYSewLP/8rqZwMBgnA1Zjap
rAsSzWadVR+9INYP0OBn0NuFcgBkh7r0DMZ2BaXFFxuBamLBABtSFfescRDGAC9ui/dhMxAFrPo5qPry1d34OMVeGll3zawnicZZ+6PlBXx052Di+C579V4M
vv1/QMOXGGblmjnSRRWlmYZJHTNAUrCQc9104P2er3CLwCkihKvABwU1GWtyFVlqx8ogAnchuviDRe1btgX/ghEQtY/p8o79VTM2os0PoT2P60ZF9CfXVKrQ
VDVAPrw35aGZlE9qvmpEF3HeThsYviOHbdST2fv3VG8NE8WghQFIDuhuAmTpCKq6cMrK/sxzDOrJM0By/VVdgPIYoZVCfQDwlXqOQcE5ShJgGwEi1xs9hz8Q
hoi8vQtbvNmI339Nj8fIxwI74V04W19NMyukHBSq0CXkWiOoydVeqVoLJVjc2qm0tHABlbodiK+Zb3lGqmNejDYgDMxBmcOGlv3Mn5NoItlxwJIJVIP/k4kL
C93c8hl6HyyqVyWvoSfbrSDWAheBpM6u/9AEk2g0GoNYrrH/5I+/+5hPP29iptvRuKWJNgOYaaqCqaBN+aPJs4iG1LWsKGOzoYFk7bB//IOpBbLDpgqoTM+y
SStr0KIVq1nu7kWSCX8lWlZkkvxpJMrBiLltNra6zRZqNvn/pGawP4WKIC52Oi+B2ftqmHUiVsWTxHdzTXTT7Cpwch1C1ypq1AfbmoGwdtfRH469ZGrN2Alv
wRe/2jWJlrz4d6AeZWktvDpS+AJqxL8/dB5bbMIvu49KDUDMgr1DQv3zT6iAV5kKEMx9P68qRjiczgAMrrq8oLFoofC68ZauD1MxtZI2/9PvDWezo2g8VAbE
XYuNnyNrNgElhhHHi5v2hyicohPSbUAfiu5iFBYTx4a2Y1R/zh27yKlcK1QdVpzeyEvVJ9WQZuzm/unk8gJU2eury89AY3B/e3Z1enb74dPl5cn11R080gCP
vMDyfQQ+bt+6vmvFLnYPcBGogVYEKuGNVqpIdyEhMW7kmOZaD01jfjkp0gJOMVRu33tOMjmgacbbc9cbT5KDAsnMlmL68HbBXrPJY3GO0cRkQ0eAuQztZyiP
G9gI9TErGPtug7MpTj5wLk0bVvwYOi4gxnKuAz9dlyr4bH20onhi+e2TcJY2hmDKgckIPcyWvCMcqYbjfCpwlJ8CX45z6Gj1pD67rJkAgfHLEJaPYJyp7VZS
wrWgYDlFOitQg6aqmYoHQ13lA8oboXcfBARIJCrSKOEJBquUsKf7Fns6PyiM9omIqkqHBLYa1gkQ5Q10oVOUISAhhqhYojTI3q2w9GGlJ5IMvB4Kk6eMJHHd
G4pL+YATJ3/Cr6sYPoP9So6BAJx68SyM3SLnP5Xkk+i5lXW0Lln+9VKx9URyCyQDbqlQ0acgti3fdRpDvqgp0IemN3i6B8hPCi8/ncuCIjc/ESNnMuMpkxZI
LPT3XAF8Ek5hnXM/hrg/1CibKiVr2MgftCVF/KlYItq8/8T/vFUngNByUFgnUbf0HTalAb0lndMG4JHFnl13xpVQ0GdTN2I2UGXkgvSOQ7ZhTdkFtPoCE/LT
hgRIPxAXLASpw4Yus4J44UIbNkwZqENsOocFG0Eqmm9sR6Hvx1A9WbhuwDkyZtn6XODIyP0ysKYzaQbr+HFCuHXZpRUnHMXoEhG8qarLhWkw2Jk0rTqz5ZPF
nTQoEeLERTLf1df6ZQfK0CPdbAAlvWaddncXpPOyWyze3y1oCanS8py37EDLtFssLrW0Q8AhVIJOtmAATbZNgwMLPFzQgxQfpNkDvTUiiiC8pvq6RAk0daS4
kNnzSFnJgkcd8DOfAVmEVg+56lMqhz/veIcs3dyslDxQHyodwyJPL9Jhm9DwNb1GE/4CMjfhlXUBlPW05D0toSd8Q7hSeyr3liEUOX62fJA9Qxeiz8eDUgNA
wsPz5uYjjq9hs8ND1t1rsn+w3u5uE/SZhijcz8revcObP6l2XgSNdNgmVYaTZ8YHUh6jhaMUty/dYAyCHom4DrGONxrpc6Rhz+PY8wB7AfxZD3UWoS4byoMH
Si8ucIglz4A9GgdS0UdYuNtHw7jRsCRWtnDZ49fNipZjrSU01TANAACCWlQFZ2iAo0xjBigvM0GC2YF32cRhbSLMQ9bbaRKaNzerJhd/mtBqcEnWpNnZZoFp
NVRpgHBbs3AMQHi77NRNQG+k1UN0wGhdXFMAEpMTJHXluvTi5N2xFR2CUI9Q0qDvFe5jBNESOlNLdJQ34yOKbTKcrDj2RqBtQqvqFrHd9q2h68s+fqb145KK
DH21aDx6eycKZ7L5KV4b20HF2PVHelNQEONEtj2hm/oXhDboh7J80eaGburbCDzH9kqPOIgyYNGExmQ0a3U/5i3oPnxfvGy/MuS8gtBqkW6lCy3Bw/ymNOaI
Hb5n3Te7KIbGeL3T4ZewdnQ7VDykYnGJxT2q0oiAtcZNas8rUsmQSt7sSlSUX+pnCq/4vq9Fr9LdpYFGNOhuJ3+BPn+BMbq4abj7eQEf/16nevzH/tz9zsMf
VgwfBJkc8o95AZ+Efg3KryOwOr/3oImUev1ORkrdjkJLb3L87xeppbtTM/a7CJTO7zV0cmIu5QLy0Vo2olZ+PYZWTdDjpkFWwwvyGnDNa+jwvmDnuJTgSjJE
xa1fwlUDOt0CuE3CzR7i4wunO36JpTs1NHg/8RLXiyffFS8r3rq1EnOl1waQON2CAFQc7Na87KkVfTcCyGg3o8txfknUmouyGqkeBLBCg8Fkg4USBmBx1Yt3
WnxJDz8ko4Y3aQzTxAXVfNqSPivyV/E/Uy8AW7WIABVQ5MZCo1dKGzpxPtCOiv1c48Qy6ZBToZYWVMmyp2EKiiJqtt0mIiXxgnnRw4/W14xDppE8xDOugHsH
jFqDDCk3IdMMLpC4frVAALe4zaUXkaW21RWGF17Y0LakJS8mHqhQDRjGIdhHayjGOF4+2K2t2GRHUCW0jWbA7Qv0ui3pZgtLX7OFwfIIkqJeKXGIjd+RLUhv
DbcHWfkhvGOTvyeWm9ujdYYWI2Folh7I0kPAS5PjBkor+z7k2y7TBxx/9xHVyS46LPICmKHC5NGTg4JqrL/QAqtIwJtFwJuVgDdrAKf6YBfFwS4qB7uogfmO
TfSxLopjrYK7WYb7V4lHkCZBCgqGRrZtHzlOQ92JX3aQvpGgkZY5Gf9l9K1J+eXGJjOChxWDVl8QG0qUlN7VgakKKa0HvBjEX4eRO6nLxqjItViPDVEjiicY
AgarQp+FXN0A7MBLWs0iTGHDjDx1f0Q8I5E/tJyxeyD7890vrihjYGWhH8p3R4mxZQA20p01PuAt8Q7dYIlrrEyz5zqiMneXbcVJCmObzv3EQ0vE3FzuJ9tp
6QWE8/sEcUbhJIqvj2v/73G76Ce2AVjcYG/zwi4WEk614h4WI4a10j6Wcjxj+UaCWtKGSnzKULnv+A82dpN8MMLjJPhL343TyIdMPjMB5UbkFH1rbqStQPhA
XX9KjTjKX9YG59R5UQvLp/MCq5tAMUMLkr0v7N2pIMlwPWSZSZsB5Q+qRoJm6yGThmzWiIqr2pC5esgyEzZrxR8YmnFjlWUGrPE16DU5a8oqGW/LcqR8sNLd
iNiNkGJkBIQ1mTuDErgCLI/z7TBMknDKzj+dqtSmR7p98qSTYwQcJi9Tk7NjhLK60+6gm0f1xLOVPxheEs5QbIbzyHaJa2dF2LC2tN90Ol8BW7xn/AwiDt9f
h7ykUYMZ/RWQUfIx64uVWNG271owQ8PQipxiB3zoX4OWiDaWYOK8qTXbHlpjE+j+PgVm8BfZ69ENx9f+TkWnOVYms208XzNOMzooYKbX31Ug/rjODAB0e2Il
0MXSiOs9CZEPeD2IJvyWN/Cq49BuQhC+RNDlaCSp3CurA9WUHsQlVyTlbQq3k3wXSO8sF3WZD09uVvNe7vmf84ydjO5D+QyVXXyuW4NR6P2W73KI7ZEO7nLg
k27hyZtep1lq/zlvz3dDOju7vP3nbuHJm15xoyTCbXre1RYfDLSc8LLPouyzoujj7Ed5bEZUDM4orgVZQ2mE3QqJS/cRWknR5BFs3p8ryo8ryq8ryu9M5Su2
XCYrN1ziyKbNFljWCSG40XLPbxBjToz2ENokUcEoMW28QJ2XbLvMlg/Y/SZbmkwkirVCh6bdbAJ2H3AoWJVlMd3qDxZXV7Th/kJq9fP6rchLR42O128k/GTU
7Hr9ZtxFRa3ualqpu0K6p8ULzlVPSr8lmGEHt67I02ItzzMW6e1R8UERxr0Ko7eTAdlToNxnUHb2OgUwpS2BaibJqMUWXgIb3QS7+LeaPiVnoR/Gk2ow8Nlb
cYsKMLCXvEXFF7hK3qLGC8z0FnCso1X1gaD/BUeuOFWmICcWKCsU91S/I5HzI0dCcUsoCy0Xm6WowBDsdXgBJZX90HsEoWQ/dB5Rw+bRY/ZDnxd2RSF3T9gP
OxUMM0HfCxIHRZcdcjKA6wUvv+fXVH5f5XGRsORSssClBNr32511m+AwtzHSDYOIaAnFVT5vW2qMamEW3GNFxSgTIoY2eTcEgkg8HWBhVyJPFhpaprxl91FK
OWyZdiWGN4trQd5S2E9AUsanKPsaNLJNGgs6b3sI3E75k5Q/ScUTs5RT13ECuo0rsFKCq/l5sw77wzZax+TEJOLfaQL1w4IJ5P8BHtzCuh82cHkHwLCsD4GU
vBYyM+O6LQokHs7xnp3fYFiyO50lqaEfbldDLSs+xksdamycOWFl81Zo5N7AmNZoCFKFXB3D5hqCEV8DTAYMQyFc4IlyD+wgx4qeoXRqeWSfYNwKKJYTjFtx
aKPUdd5SFEzWPAxcg4wDoAkFudQYhpkY4AQNQoA2J6vkGyp9zhy9hRWxzRkB4oyukCRa32G57yLssK24F0DZzbbEQyTBLSJvZN7eXvFpyp+m+LTbR42UvwTX
jYcwjOfVXq1X0KaZIbU0zXkDsbbImgfajIuYJbI1Y5jbKEqZRf4lxv1LZE0CKWyH+Ed4mlRT8yvnbh1sG6Q9vHiWnODsX3OYdYxVC2t5W52sV7jMwXQo9/26
tiUUWZHLEjTZgNUt3xsHQNDIKS4OBsoWngNzaEn/DKEPsBU4mDPBAD1wlwmYxmoA2XQOGs3V9R1y2BS4xHrGcC/EvzYW43uaifBQLL5dod/UIYsOcgK9KHRq
RmnWlUOEzHvYpw5wmdQeywH09lcOQFhFi0gJ7whFNOZ2rlF0WzJGsyK4BAC8I2uW1uwIhtAtrKLFVsO2cFAWWLFSdMoruYkMBKyZqHq0Xb6OVBmLxDit3AWc
m4+mfThazsXaqU2v2JehtX1LPOoXNdgRhcCBiYb7Hn8YgIkW1bAKoVY5NIEORRkns+qI4NCC3iDtYYtuab+2xdJj/pi6KT7OIQmEDN24sM+kmW/pEdlvcHG8
0oCbeASpBUxo2LrSrLQlN9PgovtSOy0VZqHJUqNlLMQtQs1fLY23oss6N9CKXuvMCFMf7NADaTHBE8XqqpCVz03Eimm7DHBUH50l3YfIvYjQQ3oVyceI620q
f1tENDmPkEtxaptygkdRzR4M1jHxG+EzU69WMNtKDsskTqfFGUSywU5PmnmSRTq0KadTfRlEmoPYlxBIl862+88RTotzw6Ze1czBKOJSuk47lTHvKNhRlSNi
X2A8Qx0HdSQHdQscpFX9jlzBLX0KRUBDH4detYGrhGdgVXq3ajIV6CFcZOtSj8xSvniBesDRky2bvexhHb1livk3kBzpgcegLtyBXqBq+O0lp79ugYT6HSHz
tdJeiVpw9oO1YOc018tBK4V7RdgCoXPc3t8jWoSeDpWQLvqjbQ8iv3DH99hPZ5MY9xktPiUzwCCYMzM6gWjZURjHoEyBNAhHIiQ+QiUrmahTgK+XvVkV+uXu
K/3tCu+wuAcDszgbI4oFJ57CdyqtbwXfJ3DhOyZjCDoHkj8P37N7EUBwXxAPI4rRpkap0iilRucicOC8LFMy3m0pDF1avagmHbpQNx5zqwCIFh0tYbapRiXQ
ohCZDjVOwnkxrOM/KyxM65BEqS4MSlXKXeDPKDJUqK8QUQ9LQuQjKkzqfaYvSlwBJEO0Q7lEcWnWCjpd06KpVn3rBUrMgqKROPhyS7s8vaoG2RS/I4rB/YAd
I3RRQthatRmDLzTAXb6jpKFyXlrkQCPnmcKqCwuaKAXBm3WlRw3rkRalI22lqLINOkyOm1pks6EPBARO5P60YY4tAxhHMF14cMrJ7D1+HEjIsnHkpsI3tEBI
uoOFzreD6TcULwXwLL75nEGJ3fHUDTDQjeCRLT4MvwDRwFIBdoyPFzDscOaCIdqumgsNR+uIx/Um6UXqR4WILEjAIvyS+FxPRIrDPPAW4zB0vkp0lS2FGmGr
wf2eStE3x1+qkP7OQFwVbm1ArjrBWkRqr5dF5fLg9y8iELta+VtpjiAdFGtIESoi2QzSEkbQaWOMAxKP2rwcBoZ0JgARpR2qO0LiUNk262XCB/81yZ7YGrns
9zBw+dnCoTfmTjgRWVJ3Ip8HDfFIlAKTlqKnYEQ1cltEsyinMFZtaxelgrLjlG214gb1edVGq7Y7vdfk2676xnRznUNvYpP1voYl1e1y6mqZdSX20HeaL+VV
7Pm7cyqdaMZQ/44S6t8TAdNb4kRJJ7un5z2g3mk2vPqtUXm1el+P2wvKrp6yrVfe1xPkJEx5PTRqjf2+8jx/+z6fyB8hBv2mk3krJ8XCynhqgiAtw92eCqJY
WgVDcI+lujhpl7DclcW9mLu72IPFvZj7lfuISqCnAlrbTTR4XbA2D5DCTuj2kHNeTUw537oT04CTQht0KGN4eZeX9x8NG3elTbvilt2KDTviCKKq/Pg+zrXw
HrUjeFN+gZq6pD+QR0KqAZvTY3oHeynvcOR2eiBhKJKc0kbwrck6/6/ij8J/TXI+cuOZtcCja66U9YObiytUD11M1iNM3LgiCYvYo6Pa/4yZDUw0ZRT/6qG6
6GNC5hb74kYpWNCu7Y1wfQj9cB5hdgjgNxEXmISzLR7ZBhAy7RN0SdrCjCe4bIE9L6J/xaC3aVyxzaOQ4xDr8wmDvrH7jTScM8fDMNvYGwdiOcJQsSjku4Mb
DVhK0uYGD+cEwecFVuT9jqeGZ2Dub0Kn8nChBVouQL25+pnE+PXJrWHFEsG/A6h8EoaRwxMb1OTDqDyyqUknKWzQkkD58nReUC/z9WTBj5nzwKp8RZvweK2+
MapKbdndpZaTQksMsdRbTr3gN1Y8gAGFn8uF1hJr4nEMuPxMlwXDv/XI6PxsZvfziI2XhkNpFb8+jgmPjzciDKFKMXwK16wGoBhWruZ3X1mj4soqruWKu64H
IQwekLQzX0ClJ2HJQ0l+a8oZFadNljysBMv5/BlOm0gYKYfxuSkJQJw5STmMz0058Yatu6p9ZTpNhD2/q0yphJhPkICp3hZ/AVpv8QA973OLD2mzaJERW0Ol
vRZxOp57zSvoWWrCeVJIVJMgr3AIXFC8xqUmmZhK65KlVCkXayZMwYE1VxH1uH3iu1bUoAMJ7WMfjH+DmSR6HIS+5xxH83jChjI9RF4mYJA/y+DKwp+JTRMT
mxobKSybmFi2+KPdoeBBzPuyJec6faxvx/FCG6BZQqZh1BIyfymnURakeYH6pzKIBX84N21cByirkUjxJMjgJhjXneXBBuq6bcxwecvXQHGs/1s9VoOZF9zj
Iq56rJorBqG1M1tmlbtYWhTxvp5k5V56/AxbVx0tqQo3yUqhwlwNWelk4T4Wtgly9dutOeFg4f6VAswy3Gyk/16zTZzQzg/797r5Cf9uPz/z2ut2Cke0uQtE
OSHfx9gFRHS1x6NE2XxiMD1ApyMi1f6rv9fBA2V4aoVSMaHS2e3sd2YrNFd+KuYtW4Sh42IImIPBLiCDLSBSMBF5QqIWiDDXiVkPd5ArzuRqfgs6WlPttljn
tJz5XBixzGweZSmQTIdf4nt4m39Lxodenlugt5MTxG5+BLr7o5LyoZsf2ZfZBgr00Ks5wH1Dr/3veC/+Kvy1uvlrdffz19rNSV455d3b7RXzKRQzLnR71W8I
q3M6QLL7/zpRQS9PVPBjnqig19FPyBsOp4iTbEoOlpd68lQwhYPu5dNweaIvB2v2q04+gVyhLwTRbm93uw8qY/yMluTMt4LnmE1dsF8RTogxpGzoh0N9Qha0
D7AN3QDuJ+T7xxvDujND4ULaDV29Q9sdr9aKls98l1NUPKeTx4qFSFG6pialq7wImVSvaZXqZbY0iAN41JIh6rU8RjlIHCVMD1DRK2iNBevpiHKky0L7Za26
aB67/ClrcQNXeoALal8qD88sZdHStEZrgPAEOU21DJoiiS4CnYQcxG1VjrBq0wx/5Q1a2QW0Rn8qDnVa5VItQ9DvgPgnYeT9HgboFbX9EE2At4Lm0TkSWBEq
JsQL/IBkrPACrrcaQ+Avzx2RiC013MTt49/VtCgJvodiid80p2C9hEEpTaXW1yqqLzVYh9ZVbBcQjZkAvpbOhGENFu20p0CVeRUMU1hujqPGBkUYmythlAkK
pcu04A4t5Ddb6YWfLlD4KatRL3PD73yH0zX5sZHXJHfzwyCvNdGrtdHi2e55PBu57gVjwz+I0YrIN/Ln6zXN/Sz08BburRMZHHUfhPxlvnfX0rzvr4ved6Vy
0Z+OrmYaHf2zrThRtfFpew07+UZBvn3Q69RvFEgw+e5EPw+wnrwIzJp7DrJHse/Aw7nkvkNt9LS+lbBXe1yJDqtnNgMPeI/J+8yOr+/O4doBlUMGfIHkM04+
9yNlXLAnmUBGuZtJZmgFzr2xXadNwXSLqpZ+KR6UIj5hGEDHvkLy2cNN3lsFvEiBl3MJkTNv1oIqJkZadrnDqwJuWgo6TSk5qpHV0irWwu0B1LK5E4CC9fJb
YwAE/nS7P4+uMEaG4c8sv7Wlw8+CKXwZTZGdVJVWgBY3AYwgR18V06V1EGUdRGt3kCGkqgdE0Sbwmk8T6nMBZcC1OStOHuNVz3HZLL2jDrl7h85fZxOmPqnl
ynxbjwYrTuPJLT2eTnbtc3gv3NLDH9kVzJ4IBZxuTYqIPeFHGXHW4JqoPeXXxC44h1jepbXA2D7b+cNrue8H19xfgK8rlUrTlMkMQnZxO7XGFaMkDMJ/TR4W
SlYickvTnp3rMJ+CZIfoxuGBX7SOe4k7XcO3gslO1natMJEyYk5HlTCxQyaAofcax4vy/rjVh9gUiSeU9qh7T1w+cC/B/CYrLFievyVPQLrKfm1l2WSMliwH
VzBkS8lg1glfIcmdFjMrdHu0/1d0le7vFff/yt7YnUzOq8VaS02qRtKdGq0Rs7aeM1UKwFz+/TfzpX6vYLUR+VvQ1yTSe2beF8wN+e+IodnPdHdMOVpU3v+D
YTK5zrm7a9I5++vEyZSPBebK74+rAWTnhjA5Cx6Wbe+tU718fL5fuZCujGVBpJW7sotxat1u7Zt8y9qIkRnjIBThw/wI6D9BPV4EYJlAqTWPLAAwcxPmjkau
ncSl7imhlJIAPTucSYdE8ak4rCxIcW83OwqTV8XjoA1eF/fqpa1ZalX1HihumTz+jTfFxd3JUxQcwE1maOJNlqeAnsjUA3iTreVOtpRrUOVq7dTtAa6xPIvv
MIhEZA2eWmxb7Is011iOKWHZ2utxzYprerR+yrlCQ/Flk0JL1YYuJqtTl2mRnY1yrPMU4/n33fg5lWHoOyzBU860WzT0KVPCPPE9sP/8FHUNEWYkEPyeawkC
sxzfVVqC6L6U5ny1tqDnXjHqDAJ4QWkop50zb7J2TJusb3qmTVZNjuw2DVuub/qGz2SJ2dWcHkqtuk9lEbnXqj2VWWoV79+LsiOlWWqkpZYXaY20SFU+w8Jx
HyUdEmYGqkgM9JK1mn8rLFursww/hpWan6MBIG1xWqoa3cAamHXSSRnxAJL9jFTuFBCCuQQUN/HYmhnHiy3N2Yd5B4BjkCUgStJuy8YBfZtKYau5Y3D+bDUl
DEotW00kw2so+WHS4mlfhClCRUnK2EbLkrY6yEFe8f1CU+5kQg2fhXW/xAF4uERHA7as/PKGz8d7yd/50hzaKkkhWzV9WjZtW0mC8GYtn59NzqVLRGh2DnUv
U6MucSq2COuFp+vAfUftmxwKLp7iMI6d8mddekbebbs4dTkc7PqStCUaJcLpSjj8WZ+e9TkcgyV+iZ7UzaqETNnEr5GMQY7qFW/UFFRQzPNrC9oleiUabfHI
YT3Zr3EdyD/gU7EOFDjrEjmLhlHHWT5K8kuurV9m2ro/odI+L+Xqelmp9HMdvZu7l/1cSe/X5/sgGLmS3svJy18oMFbr6TSP71hlwLjZj06ttmkIr2HUdaHp
nX0tNP3H2tB0n+vzApuXuT6/FgeXtHW/qK77K/R1nhjZtaJj8rabxVZtqpwyqciRUSKOd5L9e7S2U+YBzorwWr2VPkM6zv3uvSSsHYrJaPMzdVSWZTiQEuUP
5XVqkhQpHXQ4MCJg2UGHd0oLgr5dtW4HZX4XzZRXZoWj5i0WhPipJVV9L5pXui5PWxE+mP26XkorM0Wl52fXoRK/5M45Cq0HVbfMZXbxsFF3hzOavcw4TTh+
fqzn15LlCbZtHTeMS7sWPhl9mm0POufYuNWAdTcLdQ19lHYcNDra72SdpMVdEp3gqjr44n3xCsc48acHOYxTEeaAl126LMcFas0otmG8FNENeNmlS3Mz81aF
4gpLsx2CqrAFcomZfWJGp1itV0wCnC57mmtM842h60t4x3rq/Eaaf0zUquiDvGQ93APclV6yHrnJeqjU4EFJmh/TTkiZY/lU6tuitQsMLbTMlyHhdFv0HPgi
u+EluQ58kbHwknwHvkhyeEnOA18kLrwsuXV8kY/QR1+CL1IQ+kVvAmgBpFX4Q7PGgAnD3CgGDQFTlL0FYUGxliR28JCOcq5cyhdKASaiJ/lxchbMp0NM1I7Z
xkB8aVaGYmvnAcd/CDMVP2/GtBq8SDFE1G/SynWI45jbAvNoZc42Xn2G1ZW+1lm/Mr14xvOT2ZrfSWogqttpxvOQ2SJfnszXki0c2WZMc+WiUfgmnIahFQ4h
02fisu+x6b6EdSPslC+7GT8Y97J8eoVsh6s/s0L1ZcIz0iJElskmfZKNfynAmD0Sf1nmCpHQkhrJbxLUt4KK9E2BFZkpC72sn8cR0ygEPP0mpuKkbPiS7yxQ
yGGdFgMFoTdPyk5VnvhwW+Q4NMHnOWxArwvFWTkr5rketpi7tP25g590TZMJWvWUUSLGYGiZ6s/iH/IQgyvB54HLMkuOnCKzKveK6r1gV33tDJdmCLJfJX1i
5ZeHim3qUxPurQ5hqQKmpNPMci3vZvJBYnKF3oq/dVK25FjnWu1LqZ8CFmnSVrHZalboEgz+uY2aBKBKzrxTQAS/zc4LVggcC8kjg14ndSyRnPEd2xVGaLX2
+gpq8wS4GFaUSZwVdqODy7LFqQajf3tt9CCmvBBn/5wXmhtLrWfwryhpOBRaijqtQ3GnqcHqRO2EkCVPDxPWDuT3LrFb8zngl0ns7KMbxOZkZEoLExaPUcqL
U6X4vDzW4Rp5TMmSTpVsmOIjDf19cXNI32ioaw6vrn51JD92Lb+Tfsi0KiIzJyu0Y0MTfYoO1D2qvz9r7LoJX02SSgxOk1c7a3jbAj2VagamIqGqk31dy0lz
UdbPjXAEkKEyfIG6Y/5eqq7T0Ae/jwLQNkE4yaOY9JV2qai0WM3B6jWPUNIn5ysm9wNgko2EOoQ3jY0TkKkhqFkbLdbdaVHhAL8X1T4O/WL4G37Fnr7FMW6p
4rjFPw3VvvRQv974eH0FwEb1bYVYlk15vkxofHN59PnsdnV70m9kawzCgrZXRx/PTg1Na6m/jCQF1zegQ8wEuuBanBY9SS38RljFedFxG4ean8KcZZ/x5ekr
e/l9WrjnjL7JdpQqXYWsyY+/Y1j3eJ8Dop3GxuDs8gOiocXojCu66mnE+TA0+JusV7suqrhwSsj4CDQXJFYLeH7t9N9im5ovf+QZWle/KiEXaMChF8LNbMUq
77b4jvYWPW4Wn6T8Sdqpssh1jJ7eXt/oGM1eO+vdhMgyMsvWuiJyjMRZHs3g7ohtZD6jvD1PsP8aP1LbhMcb/0sf8mfX98NFS5FxGSWI29I7KCnOp7PVZ3/1
3WsSdxnb5mJL3Rn24UpwMUbkZfIvscYtIa0qxGCRNal1r1LylRUH7Hr1SfMSLw8zLh5m/DtUOVfJrLwOt8Kb4lwpEzqsmMfCyXV44WaeWZSG0t1fES1Zk5rP
C2ZgqRlDLMR8QqdhlMBaZQXXI5kBJChOT7zwMAtKI2jfhZ9mMze6CL5YkWfBWlM5OTZmPdm433ibJURcdjHClIqPtOIzWTzQij/I4lO1uFfQV3mVM61lT7b8
31pxRxbfasV9WfxB66dr6mdwc3Si9dV/I1ufDU7UBx1j+w9v1Do7edfdjvZgpybohjqt4s2BGzi/uGlDTGxs4yJBtvF8VpzWi6ubT3cPj0gmgul4SVeL25w9
dB7bSTpDa5CeP/1y9vn4+uj2tFTrU/vZay9+fdZdztpDpDRGX+4KzDWcxQffGqN/Cbo5+/Xs6u7D0+Dk6Ork+vSM/cka8xn7SXkEV59uMC+2wiWIgwsk/Qbl
YZzhQhHFE8tvD7zfXaBzfJtw1KC3ycIRqtU7wOdpuAgy9gA1BfVKiWrBPFTc4vtWWZp3M7RPs/VgofFdB+rOKgGSY6X7AzZIQZubtu8mmBcY6omr9sB33VkD
8+yI8Yj6Bor6GM5jF9V6cv1nX4eb498RTpXpFHGM+7M/uwnv/6MLg7TjBq7Z8cT0pFsI1AmyVEG0xt/iVlIDjdC93d3+brtT+KZBzE+aFYGkBiBpNZBJEcjX
MsjH60+DMwN5T4G88cUCTF6jFuJAg7SiRcYQhG3gAQIv6P/oeHB9+enu7PtR/8fwi3sXNi6C5CaJ2GQROK0sqo7+lr55eXN9cXXHZgds1v5NBBnO2p8LMYYn
vgfK1l04oMRYDQ43ckdspkxARnsAqYVAWtrLf7z+9WyN8QMM4gnkjwwirLAdHdrl2Ye70+v7qzqOo+bALmuA+nRT9SFEggTvbz+LJL88OdhvLZbffP63cZXo
/O/gLTH0v4HD+mtx2N/GWUWiWslkCKZbPaauaUzdujF1a8ckSXOtcfWqx9UzjatXN67eynHB8ru+SOr/LSKJyw7ioP+MXJLMK8XSmiM+D31n5aj532lpWf1P
SNU1audSM5/uWqVDFQhTLWxhjZ5QqFajmvRc0GduIjeOXZ6h5suz8u3aBojIozgNbKg0II8dPv4HqNT7HTTMXlE4pEn68+C0k3kUh9FNGNMCkM0IQM2fhGBy
AbbVL7jKODr5Xuwv7ARewfT7H6X//h853b2JvqwAAA==
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
















