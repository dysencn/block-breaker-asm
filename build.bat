@echo off

if "%1"=="" goto usage

ml /c /coff %1.asm
if errorlevel 1 goto asm_fail

link /subsystem:windows %1.obj
if errorlevel 1 goto link_fail

del %1.obj

echo --- Running %1.exe ---
%1.exe

goto end

:asm_fail
echo.
echo ERROR: Assembly Failed! (Check your %1.asm code and MASM32 path)
del %1.obj > nul 2>&1
goto end

:link_fail
echo.
echo ERROR: Linking Failed! (Check if all libraries are correctly included and the function calls match the subsystem)
goto end

goto end

:end