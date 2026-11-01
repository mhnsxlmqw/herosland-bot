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
H4sIAAAAAAAEAN19+3PbONLg71N1/wOSq9uVYlnWw/Y4ceIpP2PXOLHPcsaby6VSFEVJLFOklqQscWbn+9uvu/EgQIKUkkx2vzrNVEzi0QAa3Y3uRgPc2WGX
XhydRGnbTdj2Nr39PWHXTjhiT37iRyHbYn44X6TMCyd+6P20s8NOFn4wesVuo6UXD6ZeEDB2PBpt32dzj23fOumUtf+vDvbOG3uxF7re6DhJvNkw8L2EDbIk
9Wbts9hZ+uEEwd478cRLX7H2+/N7dhE7M28ZxY9st71iO+z0f7K9nxYJFBU1D4239mkUBJ6bQoeT9lsv9GLfLZQQLdlT21czZ1LOvVuEqT/z2ldhCuOZD7z4
yXe95PCnn+YLGIbLktRJ4Y8bOEnCLk9++uMnBj8YzHbhxx78sN8rJVPxT4M0XrjptZNFi7TB//zqh6P2wPvnwoMeOEHzM5VUrWJ5dnd+es/+kIl+mLLrFrtv
sbsWOzlkf/70XcBvb67eF6D/o8U+5nDPguBqNo/itPF8kXhxv9ceBcHz5mdmosZbAepCNoyigL310lOY/DC9g6lqAFJv05hNWwy6xAcTNw+/GTiHfB8N3Njz
Qg167I3FaObfAf42BhTAJI6ipQZbPo3cFlsgjsbf1oSAAwi6iGJvEkeLcCQa+44+DyzgZI+/B+w0WpYwgYN3vw1oMoWSOPbjJAvdX71sANleAyE+PX5HP5Hc
FnESxbdR0kAa+34qGOggsYMrPvLs22ASyQy8cHSFIrZBryFQ1fvbD/efoI5A6/D7enwbRyC0krPbq+OlE3vfSFHYE8Aol4zvvBQkLEeB/x29u0o4If0Ga80w
8P4K6rxKrtwo9F0d1ndJQpqNXBLSJKWw1h3KFJq8DyEulh/Wy93z1Rwq+am9LQWKMvlyQuAufC8Y3YzHiZc2OjkC3t18GJzzHs78w7XFfz3/eHLGiz9uUPzy
+O7s4fhONDAVNb5zZdG6bCwvo9Wh8ZodGiifRUABZ07qmMmj5UXgTBIzERdtbXqIDkbL81UaO1fhOPruxVFDY04XXIwtf3s8LCYNXCf8b9BrczZNgl68Syal
ft86oIVd25MvVXeA25KUQyHIX2iC2RvWEZLsC6LrBhqHtO5hsQ5knv92/v7+4svg9Pj96c0ZVV11Op2DlpYJTx9uZU6vBIXaFEXf3fymYHRbRtbxyeDm+sM9
zz6A/FpA1+cX92c3D+9Vs61Sdt6nXSFmTMnERVLop94ICo6dIPGs5Z4if0TlGs0C5/tj1uAAmqDKpIs4zPk2jTOYR6uIZ38y10ndKeT/qcqrjgBBeAYz21TW
JYlmu85q9l4Q6wVUeAt6u1AOgOxQl55D395DanFgY1BNHOhgQ6rivjMJowTgJW0xHjYHUcCq80HVl0P3kpMMW2mo5pqqJYnGefud44e8d5dg4gQee/ZGdL79
f0DDlxhm5ZI50kURrZqBSRMzQFKwkHPddOD/nq9wy3BURAhXgQ8LajKW5Cqy1I61ToTeUjTxB4vbd2wb/gUjIG6f0OM9+7Omb0SbF5G7SOp6RfQn11Qq0NQ1
QN69l+Wu2ZRPqr6uR1dJXs/oGI6Rw7bqyezNGyq3gYli0cIAJAd0PwWyHAmquhqVlf25P7KoJ48AyQvWNQHKY4xWCrUBwNfqORYF5zhNgW0EiFxv9Ec8Qxgi
8vU+avFqY/7+LS2eIB8L7ET30XxzNc2ukHJQqEKXkOuMoSRXe6VqLZRg8epm0tLCBVTqdiC+5oHjW6mO+QnagNCxEcocNnTcR55PoolkxyFLp1AM/k+nHix0
Cydg6H1wqFyVvIaWXK+CWAtcBJJaPf9hCCZRaTwBsVxj/8kfH/uETz+vYqfb8aRliDYLmFmmg6mgTfmjyXOIhvS1rChjVddAsnbY3/7G9ATZYFMHVKZnWaWl
KrRoxWqWm/sqyYS/Ei1rMkn+DBLlYMTcNhvb3WYLNZv8f1Iz2L+EiiAedjtfA7P3zTDrRKyOJ4nv5oboptnV4OQ6hKlV1KgPrjMHYe1toj+c+OnMmbNTXoMv
frVrEi15ye9APdrSWhg6UvgSSiS/f+p8brEpf+x+1koAYpbsNRLqv/4FBfBJqQDhIgjyoqKHw9kcwOCqyxMayxYKr1t/5QUwFTMnbfM//d5wPj+OJ0OtQ9y1
2HgbO/MpKDGMOF68tC/iaIZOSK8BbWi6i1VYTEcu1J2g+nM5coucyrVC3WHF6Y28VH1SDWnGbh++nF5fgSp78/76I9AYvN+dvz87v7v4cH19evP+HrIMwGM/
dIIAgU/ad17gOYmHzQNcBGqhFYFKGNFaFek+IiQmjRzTXOuhacwfp0VawCmGwu0Hf5ROD2ma8fXS8yfT9LBAMvOVmD58XbIXbPq5OMdoYrLhSIC5jtxHSE8a
WAn1MSecBF6DsylOPnAuTRsWfBeNPECMM7oJg2xTquCz9c6Jk6kTtE+jedYYgikHJiO0MF/xhrCnBo7zqcBefggD2c/hyCgn9dlVzQQIjF9HsHyEE6W2O2kJ
14KC5RSZrEAVmrpmKjKGpsoHlDdG7z4ICJBIlGRQwhforJbCvjy02JfLw0JvvxBRVemQwFbDOgGijcAUOkUZAhJiiIolSgM1tsLSh4W+kGTg5VCYfFEkieve
UDzKDE6cPIc/VzG8gv1M9oEAnPnJPEq8Iud/Kckn0XJLNbQpWf75tWLrC8ktkAy4pUJJH8LEdQJv1BjyRU2DPrSN4MsDQP6i8fKXS5lQ5OYvxMhKZnxR0gKJ
hf5eaoBPoxmsc967CPeHGmVTpWQNW/mDtqSIPzVLxJj3X/ifV/oEEFoOC+sk6pbBiM2oQ69I53QBeOywR8+bcyUU9NnMi5kLVBl7IL2TiD13ZuwKaj3BhPzy
XAKkH4gLFoHUYUOPOWGy9KAOG2YM1CE2W8CCjSA1zTdx4ygIEiieLj0v5ByZMLU+Fzgy9p4GzmwuzWATP6MIXj127SQpRzG6RARv6upyYRosdiZNq8ls+WRx
Jw1KhCT1kMz3zLV+1YE09Eg3G0BJL1in3d0D6bzqFpMP9gpaQqbVvOQ1O1Az6xaTSzXdCHAIhaCRbehAk+1Q58ACj5aUkWFGpjLM2ogogvCCypsSJTTUkeJC
5i5ibSULP5uAH/kMyCS0eshVn1E6/HnNG2TZ1lal5IHyUOgEFnkaSIdtQcUXNIwm/AVkbsGQTQGkWlrxllbQEo4QnvSWyq0phCLHz1efZMvQhGjz82GpAiDh
0+PW1mfsX8NlR0esu99kf2O9vb0m6DMNkXig0l6/xpd/Uek8CSqZsG2qDCdPxQdSHqOFoyW3r71wAoIeibgOsSN/PDbnyMCez7HnA/ZC+LMZ6hxCnerKJx+U
XlzgEEu+BXvUD6Sid7Bwt4+HSaPhSKxs47LHn5sVNSdGTahqYBoAAAQ9qQrO0AJHm0YFKE+zQYLZgbFsYbe2EOYR6+02Cc1bW1WTiz9DaDW4JGvS7Oyw0LYa
6jRAuK1ZOAYgvD125qWgN9LqIRpgtC5uKACJyQmSvnJd+0n6+sSJj0Coxyhp0PcK7wmCaAmdqSUayqvxHiUuGU5Okvhj0DahVnWNxG0HztALZBtvaf24piRL
Wy3qj1l/FEdzWf0Mn631oGDiBWOzKiiISSrrntJL/QChDvqhnEDUuaWX+joCz4m71iMOogxYNKU+Wc1a0495B7oP3xcv268MOa8gtFqkW5lCS/Awfyn1OWZH
b1j35R6KoQk+73b4I6wd3Q4lDylZPGJyj4o0YmCtSZPq84KUMqSUl3sSFeVBvaXwih87LBpKd486GlOnu518AH0+gAm6uKm7B3kC7/9+p7r/J8HC+8HdH1Z0
HwSZ7PLPeQKfhH4Nym9isDp/dKeJlHr9jiKlbkejpZc5/g+K1NLdren7fQxK54/qOjkxV3IBeeesGnErf55ArSbocbNQlfDDvAQ88xImvCdsHJcSXEmGqLj1
S7hqQKPbALdJuNlHfDxxuuOPmLpbQ4MPUz/1/GT6Q/GyZtSttZgrDRtA4nQLAtBxsFcz2DMn/mEEoGhX0eUkfyRqzUVZjVQPQ1ihwWBywUKJQrC46sU7Lb6k
hx+RUcOrNIZZ6oFqPmtJnxX5q/ifmR+CrVpEgA4o9hKh0WupDZM4P9GOivtY48Sy6ZAzoZYWVMmyp2EGiiJqtt0mIiX1w0XRw4/W15xDpp58SuZcAfcPGdUG
GVKuQqYZPCBx/eaAAG5xm8tMIkttuysML3xwoW5JS15OfVChGtCNI7CPNlCMsb+8s9vbic2OoEJoG82B25fodVvRyzamvmBLi+URpkW9UuIQK78mW5BGDa+H
Kv0Ixtjk48R0e320ztBiJAzNs0OZegR4aXLcQGpl20d822X2Cfvf/YzqZBcdFnkCzFBh8ijnsKAamwNaYhEJeKsIeKsS8FYN4Mzs7LLY2WVlZ5c1MF+zqdnX
ZbGvVXC3ynD/LPEI0iRIQcHQyLbt49Gooe/ErzpI30jQSMucjP+0+tak/PISmxnBw4pBqy+IDS1Kymzq0FaElNZDngzir8PIndRlE1TkWqzHhqgRJVMMAYNV
oc8irm4AdmCQTrMIU9gwY1/fHxF5JPKHzmjiHcr2Au/JE2kMrCz0QwXeOLXWDMFGuncmh7wmvqEbLPWshWn2vJEozN1l20maQd9miyD10RKxV5f7yW5WGoBw
fp8iziicRPP1ce3/DW4X/cKeAxafs1d5YhcTCadGcg+TEcNGah9TOZ4x/XmKWtJznfi0rnLf8R9s4qV5Z4THSfCXuRtnkA+ZfHYCyo3IGfrWvNhYgTBDX39K
lTjKv64Ozunoq2o4AZ0XWF8FkhlakOxNYe9OB0mG6xFTJq0CyjOqeoJm6xGThqyqRMlVdchcPWLKhFW1eIalGjdWmTJgrcOgYXLWlEUUb8t0pHyw0r2Y2I2Q
YmUEhDVdjAYlcAVYPufbYZSm0YxdfjjTqc2MdPvgSyfHGDhMPmY2Z8cYZXWn3UE3j+6JZ2t/0L00mqPYjBax6xHXzouwYW1pv+x0vgG2GGfyCCIOx29CXlGv
wYz+Bsgo+Zjz5KROvBN4DszQMHLiUbEB3vVvQUtMG0swcf7Mme8MnYkNdP+AAjP4QPZ79MLxdbBb0WiOlel8B8/XTDJFBwXM9Pp7GsSfN5kBgO5OnRSaWFlx
vS8h8g5vBtGG3/IGXnUc2m0EwpcIuhyNJJV7bXWgktKDuOKKpHzN4HWa7wKZjeWiTvnw5GY1b+WB/7lU7GR1H8o8VHYx37QG48j/R77LIbZHOrjLgTndQs7L
XqdZqv8xr893Qzq7e7z+x24h52WvuFES4zY9b2qbdwZqTnnaR5H2UVP0cfbjPDYjLgZnFNcCVVEaYXdC4tJ7jFZSPP0MNu/bivSTivSbivR7W/qaLZfp2g2X
JHZpswWWdUIIbrQ88BfE2ChBewhtkrhglNg2XqDM12y7zFefsPkttrKZSBRrhQ5Nt9kE7H7CrmBRpmK69R8srp6ow/2FVOvt5rXIS0eVTjavJPxkVO1m82rc
RUW17mtq6btCpqfFDy91T0q/JZhhF7euyNPirC4Vi/T2KfmwCONBh9HbVUD2NSgPCsrufqcAprQlUM0kilpc4SVw0U2wh3+r6VNyFvphfKkGA5+9Eq+oAAN7
yVdUfIGr5CtqvMBMrwDHJlp1Hwj6X7DnmlNlBnJiibJCc0/1OxI5P3MkFLeEVGi52CxFBYZgb8ILKKncT73PIJTcT53PqGHz6DH3U58ndkUid0+4n3YrGGaK
vhckDoouO+JkAM9Lnv7Anyn9ocrjImHJpWSJSwnU77c7m1bBbu5gpBsGEdESiqt8XrdUGdVCFdzjxMUoEyKGNnk3BIJIPB1iYlciTyZaama8ZvezlHJYM+tK
DG8V14K8prCfgKSsuSj7GtSzLeoLOm97CNzNeE7GczKRY5dy+jpOQHdwBdZScDW/bNZhf9hG65icmET8u02gflgwgfwvIOMO1v2ogcs7AIZlfQik5LeQmRnX
bVEg8XCON+zyFsOSvdk8zSztcLsaSjnJCT6aUBPrzAkrm9dCI/cW+rRBRZAq5OoYNjcQjDgMMBkwDIVwgSfKfbCDRk78CKkzxyf7BONWQLGcYtzKiDZKvdEr
ioJR1aPQs8g4AJpSkEuNYajEACdoEAK0OVkl31DpGy3QW1gR26wIEGd0jSQx2o7KbRdhR23NvQDKrtoSj5AEt4m8kXl7+8XcjOdmmNvto0bKB8F14yF043G9
V+sZ1GkqpJamOa8g1hZZ8tCYcRGzRLZmAnMbxxlzyL/EuH+JrEkghZ0I/whPk25qfuPcbYJti7SHgavLCc7/uYBZx1i1qJa39cl6hsscTIf23q+rW0KRE3ss
RZMNWN0J/EkIBI2c4mFnIG3pj2AOHemfIfQBtsIR3plggR56qxRMYz2AbLYAjeb9zT1y2Ay4xHnEcC/Ev9EX6zjtRHgkFt+u0G/qkEUHOYFeNDq1o1Q1NSJC
5i0cUAO4TBrZsgO9g7UdEFbRMtbCOyIRjbmTaxTdlozRrAguAQCvyZqlNTuGLnQLq2ix1rAtHJQFVqwUnfJJbiIDARsmqhltl68jVcYiMU4rdwHn5qNtH46W
c7F2GtMr9mVobd8WWf2iBjumEDgw0XDf4w8LMFGjGlYh1CqHJtChKeNkVh0THFrQG6Q9bNMr7de2WHbCs6mZYnYOSSBk6CWFfSbDfMuOyX6Dh5O1BtzUJ0gt
YELL1pVhpa24mQYP3a+10zJhFtosNVrGItwiNPzV0ngruqxzA63otVZGmJ6xSxnSYoIczeqqkJWPTcSKbbsMcFQfnSXdh8i9iNAjGorkY8T1DqW/KiKanEfI
pTi1TTnB47hmDwbL2PiN8KnUqzXMtpbDlMTptDiDSDbY7UkzT7JIhzblTKovg8hyEAcSAunSarv/EuG0ODdsmUXtHIwiLqPnrFMZ846CHVU5IvYlxjPUcVBH
clC3wEFG0R/IFdzSp1AENPSx61UbuFp4BhalsVWTqUAP4UKtSz0yS/niBeoBR49aNnsqs47elGL+HSRHeuAJqAv3oBfoGn57xemvWyChfkfIfCO1V6IWnP1w
I9g5zfVy0FrifhG2QOgCt/f3iRahpSMtpIv+GNuDyC/c8T0Jsvk0wX1Gh0/JHDAI5sycTiA6bhwlCShTIA2isQiJj1HJSqf6FODw1Miq0C93X+lvV3iHxTsY
mMXZGFMsOPEUjqm0vhV8n8CFr5mMIegcSv48esMeRADBQ0E8jClGmyplWqWMKl2KwIHLskxRvNvSGLq0elFJOnShbzzmVgEQLTpaIrWpRilQoxCZDiVOo0Ux
rOM/Kyxs65BEqSkMSkXKTeDPKjJ0qM8QUZ9WhMjPqDDp70pflLgCSJZoh3KK5tKsFXSmpkVTrfvWC5SogqKROPhyS7s8vaoKaopfE8XgfsCuFbpIIWyt24zB
AQ1wl+84beiclxU50Mp5trDqwoImUkHwqqbMqGEz0qJ0pK0UVfacDpPjphbZbOgDAYETe788t8eWAYxjmC48ODVS9h4/DiRk2ST2MuEbWiIk08FC59vB9BuK
QQE8h28+KyiJN5l5IQa6ETyyxYfRExANLBVgxwT4AN2O5h4You2quTBwtIl43GySvkr9qBCRBQlYhF8Sn5uJSHGYB0YxiaLRN4musqVQI2wNuD9SKfru+Esd
0l8ZiKvDrQ3I1SfYiEjt9VRULg9+fxKB2NXK31pzBOmgWEKKUBHJZpGW0INOG2MckHj06uUwMKQzAYgo7UjfERKHynZYTwkf/NcmexJn7LHfo9DjZwuH/oQ7
4URkSd2JfB40xCNRCkxaip6CHtXIbRHNop3CWLetXZQK2o6T2mrFDerLqo1WY3d6v8m3Xc2N6eYmh97EJutDDUvq2+XU1Eo1JfbQd5tfy6vY8g/nVDrRjKH+
HS3UvycCprfFiZKOeqf8HlDvTHWvfmtUPq3f1+P2grarp23rlff1BDkJU94Mjdpgv688z9+/zyfujxCdftlR3sppMbEynpogSMtwr6eDKKZWwRDc4+guTtol
LDflcC/m3h624HAv5kHlPqIW6KmBNnYTLV4XLM0DpLARej3inFcTU8637sQ04KTQBh3KGJ7e5en9z5aNu9KmXXHLbs2GHXEEUVV+fB/nWniP2jGMlD+gpi7p
D+SRkGrA5pRNY3BX8g177maHEoYmyenaCL41Wef/1fxR+K9NzsdeMneWeHTNk7J+cHv1HtVDDy/rESZuUnEJi9ijo9J/T5gLTDRjFP/qo7oY4IXMLfbkxRlY
0J7rj3F9iIJoEePtEMBvIi4wjebbPLINICjtE3RJ2sJMprhsgT0von9Fp3eoX4nLo5CTCMvzCYO2sfnnWbRgIx/DbBN/EorlyHph2B0HKU5Jfq8BMJj74QPi
RDcAjDXXrhTn9ewLXaVT0AjKOjDPrD9IA8riCewYZ9T5CleKvOKzulZn5Sor2wJh//2Lo9BXubpagFmGq3r6710FxYG3/Oxkr5sfmOz28yNEvW6ncOKNa5Ta
gcM+bgUhoqsVyBKD84nB05adjtj4/6/+fgfj8zEImG62QB7udg468zWCgAcZv2JL0Bo93FEf4d5hOkWjL4UVl9/v0AKx5Y0S1kOHfMURJ0MNpEjlai1wk8MH
9jB7Ypn5IlY3SthiiZMHGM2/5QBtLz+q2dvNCWIvP1HW/Vk7QdvNT0DKw5sFeujVnIe7pWH/O8bFh8KH1c2H1T3Ih7WXk7x2aK631yseTy0eYO32qkf4Nnay
AZLd/9fnPnv5uc+f83OfvY554NAS6ysOBmhH2r/WMNLBFM4Nlg8X5PemjLBkvyqQHOQKfXCBnOfdnT6bOckjLszzwAkfEzbzQB1AOBGG5IBBGQ3NCVmSW2UH
mgHcT8mVgi+WdWeOwoWcNvT0GlUhfNoo+FCZgjPUQWfTzxULkRZ5OytG3pYbMKpqQbQzWxCtvTr1EzmAbwJbgojKfZSdxF7C9AAVPYPamGBrs9xR2dNVof7K
2uf6vsufthY3cKUHuFvQIRmLvJJJK9sabQDCA3k01XIPmiS62DcWchC91Bxh+TVMtl/Z3y2bgNponmJXZ1UWahmC+QbEP41i/3ewEGDxdYMIL716JWgetdbQ
iVExIV7g500SjRdwvTUYAn/5UdxUeCjRJ97Hv+tpURJ8D8USf2nO2qdBFJZu/TLaWkf1pQqb0LqO7QKi8WDlt9IZOmXpEC8MU4Mqj6laprBcHXuNFYowttbC
KBMUSpdZwbosXBez1qkxW6Lw01ajnvJq7P6AYOU8CvcFyd08tvaFIXqNOkZ4wAMPDyBPiGBs+AcxWhFIQO4Rs6S9naW5W8idK+JCLHP7UP6UK8NzDGfGi6Iz
QytcdE+g5U69o392NJvU6J/hutnN/S65N6bXqfe7SDC5s6d/YHHfbAJmQxeObFG4cfjuuHTj1AajmZ6Z/drobzr7p2wGHj+YkDHPTm7uL+F5BCqH3D8HyWed
/DldK6y4YF8ygQwatJPM0AlHD9Z6nTbFJiyragal8BoKoIFuAB0HGsmrzC3eWgW8WIOXcwmRM6/WgiI2RlphcAM2a4eblWJ4MrprzspqWRVrobcFtWzuBKDY
h/zVup+EP9PuzzerrBvt+LPLb2PpCNTeVCA3p9TBH2kFGNtQwAiy91Vb5EYDsWog3rgBhZCqFhBFW8BrAU1owAWUBdf2SwbyLfN6jlOz9Joa5O4dOs6mJkzP
qeXK3EtKnRWHG6SHlN/Ot/Gxhq/0kOKP7ArmToUCTq82RcSd8pMhOGvwTNSe8WdiF5xDTO/SWmCtrxyp+CzdqPDM/QU4XKlU2qZMXsjgFr3TNa4Y7f4F/Nfm
YaGz3+KqTnKBeiMWUMzREN04fB+d1nE/9WYb+Fbw7PjGrhUmTuAuKPIbz8kqAQyt1zhetPHjIVvEpjjHq9VH3Xvq8Y77KR4XX2PB8uPw+X1u6+zXljqcb7Vk
ObiCIVs6W7/JbiBJ7qx4ULWL96vHJVfpwX7BBRCXvbG7Ss7ryUZNQ6rG0p0abxACsJkzVQrAXP79N/Ol/qi9/zH5W9DXJG5LU94XvGrr37EleaB0d7zBrai8
/wd3HXOdc2/PpnP2N9l2LJ+yyJXfn9cDUGHYeNYdzx619zcpXj6N2K9cSNduDSLSyk25xW3/brd2JN+zNuJG1ySMRDQWP1Hzd1CPlyFYJpDqLGIHAMy9lHnj
seemSal5up9Du09WnXWhMzeYK85+CVLc31ORxXlRPF3T4GXx9Li0NUu1qsaB4pbJ03T4UlzcR/mJz0N4UYYmvqhjn5QjT3Lii1rLR2opN6DK1VpXl79leRbX
Wot7XRr8ppYdsS/S3GA5pvtfNl6Pa1ZcW9bmN/gUKoqL4gs1dRu6ePePvkyLy27oylp+Y2v+uRwe9juMghFL8dAY7RYNAzp4ukgDH+y/IENdQ+zaCgS/4VqC
wCzHd5WWIJov3Rq7Xlswj7JbdQYBvKA0lG/xsW+ydmybrC97tk1WQ47sNS1bri/7lq+OiNk1nB5aqbovjxC516o9lZf+ad6/r7psIlM3TayMayY2uGWiymdY
iJ7WbpfAixYq7ln4mrWaf3pFrdXqwgTLSs3DkgFIWwSfV6MbWAMv8RpljHgAyX5OKncGCMGjmZqbeOLMrf3FmvbLHHkDgGOQJSBKsm7LxQ59n0rh6kfxcf5c
/YQ9Si1XP5fPS2jH7bPi4SmEKSJvSMq4VsuStjrIQV7xOSjbVZSEGj4Lm15sDni4RkcD1qy8yDzg/b3mY762RwpJUlCrZkDLputqZ0pfbuTzc8m5dI0IVcd6
9pUadY1TsU1YL+RuAvc11W9yKLh4ithmN+N5Xcoj77ZbnLocDjZ9TdoS9RLhdCUcntenvD6HY7HEr9GTulV1v4Wa+A3OtspePeOVmoIKitcmuoJ2iV6JRls8
EMu8O9G6DuTfQ6hYBwqcdY2cRd2o46wAJfk119avlbYeTCm1z1O5ul5WKoNcR+/m7uUgV9L79cenCUaupPdy8gqWGoz1ejrN42tWGX9n96NTrR3qwgvodV2k
X+fAiPT7uTbSL+D6vMDmda7Pb8TBJW09KKrrwRp9nd8z6TnxCXnb7WKr9uaBMqnIntG55teS/Xu0ttNBTs6KMKzeWp8hnY57/UYS1i7FZLT5EQVKUwdGpUT5
QxtOzZ0PWgMdDowIWDbQ4Y3SgmBuV23aQJnfRTVtyKxwcq/Fwgi/XKGr70XzytTlaSsiALPf1EtpZXaePLxuQh4FhEL8kTvnKFIRVN0yl7nF2O3uLmc0d6U4
TTh+fq7n15LlCbZtHTdMSrsWARl9hm0POufEutWAZbcKZS1tlHYcDDo66KhGsuIuiUlwVQ08+U9+4VQM/swgh0kmwhzwsUuP5bhAoxrFNkxWIroBH7v0aK9m
36rQXGGZ2iGoClsgl5jdJ2Z1itV6xSTA2apnuMYM3xi6voR3rKfPb2z4x0SpijbIS9bDPcA96SXrkZush0oNnjuh+bHthJQ5lk+luS1au8DQQssCeVsUvRY9
B4G4LOqaXAeBuADqmnwHgbgz6pqcB4G4B+q65NYJxPVOAfoSAnGjU1D0JoAWQFpFMLRrDHj/ihcnoCHgjS+vQFhQrCWJHYx51o7pSflCN6qI6El+Oo+Fi9kQ
773Fy1tAfBlWhmZr5wHHfwgzFb8Ww4wSPEkzRPRP/Ml1iOOY2wKLeO0VOLw4fTlba2uT9UvpxXN+3Ytr+J2kBqK7neb8WhdXXD8kj7+rhUNtxjTXLhqFT+wY
GFrjELJ9dUd93sb0JWwaYad9KMf6/Z2vu56ocHnU+lvrqby8P4a0CHFpV5O+cMMvXrZexoU/dRBY3A9GleQVz/W1oCBd0bzmoq9CK5tfi4WnUkN+mxnebEaX
C0u+c0Ahh3VadBSE3iItO1X5PVI74sooG3x+JQDodZE4euAk/OjsNvNWbrAY4RfysnSKVj0d0E0wGFrenOTwe9FF50rweeCyvHRATpFdlXtG5b5iV33jC8Ps
EGS72m1UlR9yKNapv+lpf30ISxUw7XYydXXlnpIPEpNr9Fb8bXICPsc612q/lvopYJEmbR2brWeFLsHgt5fX3KemXUF0Bojgr+qjGBUCx0HyUNDrpI4j7rp6
zfaEEVqtvT6D0vw+QQwrUhJnjd04wmXZ4VSD0b+9NnoQM56Is3/JE+2VpdYz+GecNkYUWoo67YjiTjOL1YnaCSFLHsYirB3Kz4dhs/ZjVV8nsdUd5sTmZGRK
CxMWj3HGkzMt+bLc1+EG18JpF6Hzy8XEndf9A/FyRFde11WHoeuXuOen2ORnZ4+YUURcdMYK9djQRp+iAX2P6q+/hG/T+/Nskkp0zpBXuxt420LzZjoFpuJ+
upH6WMkoy0VZPzfCEYBCZfQV6o7983OmTkPfTz0OQdsE4WR8IlsqKi22/rvN3/Pl8QvAJBsLdQhfGs9PQaZGoGY9b7HubosSB/j5jfZJFBTD3/CjwHS1+aSl
i+MW/9JG+9pH/fr5u5v3AGxcX1eIZVmVXz8GlW+vjz+e362vT/qNrI1BWFD3/fG78zNL1VrqLyNJw/Ut6BDyW8zw3ODNnWYOfnLFcpMM/vi3k/OvjM/VVxH5
bWC9/D0rvHNG32K7WpGuRtbkx9+1rHu8zQHRTuP54Pz6AtHQYifxIpmiq556nHfDgL/FerXroo6LUQkZ74DmwtTBb9JvfJuq2Kbmyx95hjbVr0rIBRoY0YBw
M1uzyrstvqO9TdnNYk7Gc7JOlUVuYvTs7ubWxKgatmrdhsgyMsvWuiZyrMRZ7s3g/pg9Vz6jvD6/r/gFfvOvCdnP/5fZ5Y9eEETLlibjFCWI19IYtBtjZ/P2
wHny6APxLUaiRnx+/DacWO9AI3Gn2DYXW/rOcABPgosxIk/Jv9SZtIS0qhCDRdak2r1KyVdWHLDpdRRr4eWh4uKh4t+hzrnaRZWbcCuMFOdKm9BhxTySCRsF
/ogmFAfczC9qo650D9ZES9bcdOSHc7DUrCEWYj6h0ShOYa1ywptxQ0xUWJyeZOnjofJG2L6PPsznXnwVPjmx78BaUzk5Lh4if/7w/JW6X2rVxQhTSj42ks9l
8sBIvpDJZ3pyr6Cv8iLnRs2erPm/jeSOTL4zkvsy+cJop2trZ3B7fGq01X8pa58PTvWMjrX+xUu9zG7edLdjZOzWBN1Qo1W8OfDC0a9e1hATm7i4SJBtvJgX
p/Xq/e2H+0+fkUwE0/GUrhG3Of/U+dxOszlag5T/5dfzjyc3x3dnpVIf2o9+e/lb4SPnRiZSGqMPoYT2EqPlReBM0L8EzZz/dv7+/uLL4PT4/enN2Tl+IHwx
Z79oWfD04RavGdW/pQw4uELSb9C1VnNcKOJk6gTtgf+7B3SOo4nGDRqNCkeoVu8An2fRMlTsAWoK6pUS1YJ5KLnF963Urbl2aB/mm8FC47sO1L1TAiT7Su+H
bJCBNjdr30/xmkUoJ57ag8Dz5o3+HhTh/RHlLRT1LlokHqr15PpXH9tZ4N8xTpXtFHGC+7NvvZS3/86DTrpJA9fsZGrL6RYCdUJ1kw+t8Xe4ldRAI3R/b6+/
1+4UrohO+EmzIpDMAiSrBjItAvlWBnl382FwbiHvGZA3DizEL0/qidjRMKuooRiCsA08QOAF/R+fDG6uP9yf/zjqfxc9efdR4ypMb9OYTZfhqKWi6uhv6RNi
tzdX7+/Z/JDN2/8QQYbz9sdCjOFp4IOydR8N6J6RBocbe2M21yZA0R5AaiGQljH4dze/nW/Qf4BBPIH8oSDCCtsxoV2fX9yf3Ty8r+M4qg7ssgGoD7dV35Ui
SDB+91HcmcjvWvkHxyd/+fhv4yrR+F/BW6LrfwGH9TfisL+Ms4pEtZbJEEy3uk9dW5+6dX3q1vZJkuZG/epV96tn61evrl+9tf2C5XdzkdT/S0QSlx3EQf8Z
uSSZV4qlDXt8GQWjtb0Wn6UuLav/Cam6QelcaubTXat06AJhZoQtbNASCtVqVJOeC/rMbewlicdvqHl61D4F2AAReZxkoQuFBuSxw+y/gUp90EHD7BmFQ9qk
Pw9OO13ESRTfRgktAGpGAGqeE4HJBdjWP4gn4+jkuNif2AgMwfb7H6X//h+H1QZ9DaYAAA==
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
















