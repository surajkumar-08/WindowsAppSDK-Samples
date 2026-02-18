@echo off
REM Copyright (C) Microsoft Corporation. All rights reserved.
REM
REM Simple batch wrapper for build.ps1
REM Usage: build.cmd [Debug|Release|RelWithDebInfo|MinSizeRel] [x64|arm64] [Ninja|VisualStudio]
REM

setlocal

set CONFIG=%1
set PLATFORM=%2
set GENERATOR=%3

if "%CONFIG%"=="" set CONFIG=Debug

if "%GENERATOR%"=="" (
	powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Configuration %CONFIG% -Platform %PLATFORM%
) else (
	powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Configuration %CONFIG% -Platform %PLATFORM% -Generator %GENERATOR%
)
