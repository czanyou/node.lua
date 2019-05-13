@echo off

rem -------------------------------------------

if "%1" equ "local"   goto build
if "%1" equ "build"   goto build
if "%1" equ "sdk"     goto sdk
if "%1" equ "install" goto install
if "%1" equ "remove"  goto remove
if "%1" equ "clean"   goto clean

@set PATH=%CD%\bin;%PATH%

rem -------------------------------------------
:menu

echo Node.lua Windows Build System
echo ========
echo.

echo build   - build for current system
echo clean   - clean all build output files
echo.
echo sdk     - generate the SDK package
echo.
echo install - install the Lua runtime environment for current system
echo remove  - remove the Lua runtime environment for current system
echo.

goto exit

rem -------------------------------------------
:build

echo build

cmake -H. -Bbuild/win32
cmake --build build/win32 --config Release

copy %CD%\build\win32\Release\lnode.exe %CD%\bin\
copy %CD%\build\win32\Release\lua53.dll %CD%\bin\
copy %CD%\build\win32\Release\lmbedtls.dll %CD%\bin\
copy %CD%\build\win32\Release\lsqlite.dll %CD%\bin\
copy %CD%\build\win32\Release\lmodbus.dll %CD%\bin\

copy %CD%\app\lpm\bin\* %CD%\bin\
copy %CD%\app\lbuild\bin\* %CD%\bin\

goto exit

rem -------------------------------------------
:sdk

echo sdk

lbuild sdk

goto exit


rem -------------------------------------------
:install

echo install

lnode script\install.lua

goto exit

rem -------------------------------------------
:remove

echo remove

lnode script\install.lua remove

goto exit

rem -------------------------------------------
:clean

echo clean

CALL rd /s /q build\win32

goto exit

rem -------------------------------------------
:exit

echo done.
