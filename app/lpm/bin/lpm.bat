:: Created by lpm, please don't edit manually.
@ECHO OFF

SETLOCAL

SET "LNODE_EXE=lnode"

SET "LPM_CLI_LUA=require('lpm')(arg)"

"%LNODE_EXE%" -e "%LPM_CLI_LUA%" %*
