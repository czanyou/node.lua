@echo -
@echo - Please execute make.bat build the project before installation.
@echo - 

@set PATH=%CD%\bin;%PATH%

@lnode.exe install.lua

@pause
