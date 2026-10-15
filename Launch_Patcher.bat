@echo off
title Star Conflict Server Selector Patcher
where pythonw >nul 2>nul
if %errorlevel% equ 0 (
    start "" pythonw StarConflict_Patcher.pyw
    exit /b 0
)
where python >nul 2>nul
if %errorlevel% equ 0 (
    start "" python StarConflict_Patcher.pyw
    exit /b 0
)
where py >nul 2>nul
if %errorlevel% equ 0 (
    start "" pyw StarConflict_Patcher.pyw
    exit /b 0
)
echo Python was not found in your system PATH.
echo Please install Python 3 from https://www.python.org/downloads/
echo (Make sure to check 'Add Python to PATH' during installation.)
echo.
pause
