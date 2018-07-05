@echo off

rem -------------------------------------------

if "%1" equ "local"   goto build
if "%1" equ "build"   goto build
if "%1" equ "sdk"     goto sdk
if "%1" equ "install" goto install

rem -------------------------------------------
:menu

echo Node.lua Windows Build System
echo ========
echo.

echo build   - build for current system
echo sdk     - generate the SDK package
echo install - install the Lua runtime environment for current system
echo.

goto exit

rem -------------------------------------------
:build

echo build

cmake -H. -Bbuild/win32
cmake --build build/win32 --config Release

copy %CD%\build\win32\Release\lnode.exe %CD%\node.lua\bin
copy %CD%\build\win32\Release\lua53.dll %CD%\node.lua\bin
copy %CD%\build\win32\Release\lmbedtls.dll %CD%\node.lua\bin
copy %CD%\build\win32\Release\lsqlite.dll %CD%\node.lua\bin

copy %CD%\app\lpm\bin\* %CD%\node.lua\bin
copy %CD%\app\lbuild\bin\* %CD%\node.lua\bin

goto exit

rem -------------------------------------------
:sdk

echo sdk

lbuild sdk

goto exit


rem -------------------------------------------
:install

echo install

cd node.lua

CALL install.bat

cd ..

goto exit

rem -------------------------------------------
:remove

echo remove

cd node.lua

CALL install.bat remove

cd ..

goto exit

rem -------------------------------------------
:exit

echo done.
