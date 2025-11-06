@echo off
echo Starting deployment in new window...
start "SHA K8s Blog Deployment" powershell.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0deploy-now.ps1"
echo.
echo Deployment started in a new PowerShell window.
echo Please wait for it to complete (5-10 minutes).
echo Do NOT close that window until deployment finishes!
pause
