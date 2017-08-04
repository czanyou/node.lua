@echo off

rem -------------------------------------------

:main

set target="%1"

if %target% equ "clean"   goto clean
if %target% equ "install" goto install
if %target% equ "latest"  goto latest
if %target% equ "local"   goto local
if %target% equ "sdk"     goto sdk

goto menu


rem -------------------------------------------

:menu

echo Node.lua Windows Build System
echo ========
echo.

echo clean   - Clean all build output
echo install - Install the SDK to current system
echo latest  - Publish the SDK package to the server
echo local   - build for current system
echo sdk     - Build the SDK package
echo.

goto exit


rem -------------------------------------------

:clean

goto exit


rem -------------------------------------------

:local

cmake -H. -Bbuild/win32
cmake --build build/win32 --config Release

set base_path=%CD%\build\win32\Release

copy %base_path%\lnode.exe    %CD%\node.lua\bin
copy %base_path%\lua53.dll    %CD%\node.lua\bin
copy %base_path%\lmbedtls.dll %CD%\node.lua\bin
copy %base_path%\lsqlite.dll  %CD%\node.lua\bin

goto exit


rem -------------------------------------------

:sdk

lpm build sdk

goto exit


rem -------------------------------------------

:upload

lpm build upload

goto exit


rem -------------------------------------------

:install

cd node.lua

CALL install.bat

cd ..

goto exit


rem -------------------------------------------

:latest

lpm build upload latest

goto exit


rem -------------------------------------------

:exit

