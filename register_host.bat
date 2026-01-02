@echo off
set "KEY_NAME=HKCU\Software\Google\Chrome\NativeMessagingHosts\com.linkmate.host"
set "MANIFEST_PATH=%~dp0host_manifest\com.linkmate.host.json"

reg add "%KEY_NAME%" /ve /t REG_SZ /d "%MANIFEST_PATH%" /f

if %errorlevel% equ 0 (
    echo LinkMate Host registered successfully.
) else (
    echo Failed to register LinkMate Host.
)
pause
