@echo off
rem Double-click this to install/verify the components PersonaR's tools need.
rem Pass -Check to only report:  setup.bat -Check
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
pause