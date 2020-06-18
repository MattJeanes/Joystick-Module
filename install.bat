:: Clone the repo in your addons folder then run this file

@echo off

set "joymodInstall=%~dp0"

cd /d "%joymodInstall%"
cd ..\..

if not exist "lua" mkdir lua
if not exist "lua\bin" mkdir lua\bin

xcopy /v /y "%joymodInstall%lua\bin\*.dll" "lua\bin"
xcopy /v /y /s "%joymodInstall%addons" "addons"

echo Joystick module has been installed !

set /p joymodDelete="Cleanup repository in addons ? : "

:: Don't move time while we are standing on it ( one dot, oh yeah )

cd /d "%joymodInstall%"
cd ..

if "%joymodDelete%"=="y" (
  rd /S /Q "%joymodInstall%"
) else (
  if "%joymodDelete%"=="Y" (
    rd /S /Q "%joymodInstall%"
  )
)

timeout 100

exit 0
