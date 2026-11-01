@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================
echo   Hero's Land auto farm bot
echo ============================================
echo.

where powershell >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Windows PowerShell was not found on this machine.
  echo         Windows 10/11 normally ships it.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_bot.ps1" %*
set RC=%ERRORLEVEL%

if not "%RC%"=="0" (
  echo.
  echo [ERROR] the bot exited with code %RC%
  echo.
  echo Common causes:
  echo   1. Only run_bot.ps1 was downloaded. Keep run_bot.ps1 + run_bot.cmd together;
  echo      the engine is embedded in run_bot.ps1 and is restored automatically.
  echo   2. "running scripts is disabled on this system" (Group Policy):
  echo      run once in PowerShell:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  echo   3. The file came from the internet and is blocked:
  echo      right-click run_bot.ps1 - Properties - tick "Unblock" - OK
  echo   4. Anti-virus blocked it (the script compiles C# at runtime and sends keystrokes).
  echo      Whitelist the folder.
  echo   5. Hero's Land is not running, or it is not in windowed/borderless mode.
)

echo.
echo bot stopped.
pause
