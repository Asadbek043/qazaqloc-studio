@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

if /I "%~1"=="--check" (
  if not exist ".venv\Scripts\python.exe" (
    echo Python environment missing. Run setup-windows.ps1 first.
    exit /b 1
  )
  ".venv\Scripts\python.exe" scripts\check_local.py
  exit /b
)

if not exist ".venv\Scripts\python.exe" goto setup
if not exist "frontend\dist\index.html" goto setup
".venv\Scripts\python.exe" -c "import fastapi, pydantic, sqlalchemy, uvicorn, typer, httpx" >nul 2>&1
if errorlevel 1 goto setup
goto launch

:setup
echo Preparing QazaqLoc Studio for first local launch...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1"
if errorlevel 1 goto failed

:launch
if /I "%~1"=="--no-browser" (
  ".venv\Scripts\python.exe" scripts\run_local.py
) else (
  ".venv\Scripts\python.exe" scripts\run_local.py --open-browser
)
if errorlevel 1 goto failed
exit /b 0

:failed
echo.
echo Launch failed. Read the error above.
echo Diagnostics: start-local.cmd --check
pause
exit /b 1
