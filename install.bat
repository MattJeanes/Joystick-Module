:: Clone the repo in your addons folder then run this file

@echo off

set "joymodMainDir=Joystick"
set "joymodInstall=%~dp0"

:: Clean install parameter

set /p joymodClean="Perform clean install [y/N] ? "

cd /d "%joymodInstall%"
cd ..\..

if /I "%joymodClean%" EQU "y" (
  rd /s /q "addons\%joymodMainDir%"
  del /s /q "lua\bin\gmcl_joystick_*.dll"
) else (
  if /I "%joymodClean%" EQU "Y" (
    rd /s /q "addons\%joymodMainDir%"
    del /s /q "lua\bin\gmcl_joystick_*.dll"
  )
)

if not exist "lua" mkdir lua
if not exist "lua\bin" mkdir lua\bin

:: Copy files relative to base /garrysmod/ folder

xcopy /v /y "%joymodInstall%lua\bin\*.dll" "lua\bin"
xcopy /v /y /s "%joymodInstall%addons" "addons"

echo Joystick module has been installed !
echo Please remove the clonned repo manually !

cd /d "%joymodInstall%"

timeout 100

exit 0
