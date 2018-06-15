:: Created by lpm, please don't edit manually.
@ECHO OFF

SETLOCAL

SET "LNODE_EXE=%~dp0\lnode.exe"
IF NOT EXIST "%LNODE_EXE%" (
  SET "LNODE_EXE=lnode"
)

SET "LPM_CLI_LUA=%~dp0\lpm"

"%LNODE_EXE%" "%LPM_CLI_LUA%" %*
