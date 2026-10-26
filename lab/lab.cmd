@echo off
rem Run lab.ps1 with -ExecutionPolicy Bypass (works even when RemoteSigned misbehaves).
rem Usage: lab.cmd check   ^|   lab.cmd up -Profile dvwa
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lab.ps1" %*
