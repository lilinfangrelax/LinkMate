@echo off

set "MANIFEST_PATH=%~dp0host_manifest\com.linkmate.host.json"

:: Chrome
set "KEY_CHROME=HKCU\Software\Google\Chrome\NativeMessagingHosts\com.linkmate.host"
reg add "%KEY_CHROME%" /ve /t REG_SZ /d "%MANIFEST_PATH%" /f
if %errorlevel% equ 0 echo Chrome Host registered.

:: Edge
set "KEY_EDGE=HKCU\Software\Microsoft\Edge\NativeMessagingHosts\com.linkmate.host"
reg add "%KEY_EDGE%" /ve /t REG_SZ /d "%MANIFEST_PATH%" /f
if %errorlevel% equ 0 echo Edge Host registered.

:: Firefox
set "MANIFEST_PATH_FIREFOX=%~dp0host_manifest\com.linkmate.host_firefox.json"
set "KEY_FIREFOX=HKCU\Software\Mozilla\NativeMessagingHosts\com.linkmate.host"
reg add "%KEY_FIREFOX%" /ve /t REG_SZ /d "%MANIFEST_PATH_FIREFOX%" /f
if %errorlevel% equ 0 echo Firefox Host registered.

pause

