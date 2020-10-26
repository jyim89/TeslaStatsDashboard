@echo off
echo %~dp0
PowerShell.exe -Command "& '%~dp0registertask.ps1'"