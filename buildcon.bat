@echo off
REM build.bat - MASM32 32位控制台程序一键编译工具
REM 用法: build 文件名 (不带 .asm 后缀)

REM 检查参数
if "%1"=="" goto usage

REM ------------------------------------------
REM 步骤 1: 汇编 (.asm -> .obj)
echo.
echo --- 1. Assembling %1.asm with /coff ---
ml /c /coff %1.asm
if errorlevel 1 goto asm_fail

REM ------------------------------------------
REM 步骤 2: 链接 (.obj -> .exe)
echo.
echo --- 2. Linking %1.obj to %1.exe ---
REM 注意: 这里的 /subsystem:console 适用于 printf 输出
link /subsystem:console %1.obj
if errorlevel 1 goto link_fail

REM ------------------------------------------
REM 步骤 3: 清理和完成
echo.
echo --- 3. Cleaning up and Finishing ---
del %1.obj
echo.
echo ✅ SUCCESS! %1.exe has been created.

REM ------------------------------------------
REM 步骤 4: 运行程序 (新增)
echo.
echo --- 4. Running %1.exe ---
%1.exe

REM 运行控制台程序后暂停，防止窗口闪退
pause

goto end

REM ------------------------------------------
REM 错误处理和帮助信息

:asm_fail
echo.
echo ❌ ERROR: Assembly Failed! (Check your %1.asm code and MASM32 path)
del %1.obj > nul 2>&1
goto end

:link_fail
echo.
echo ❌ ERROR: Linking Failed! (Check if all libraries are correctly included and the function calls match the subsystem)
goto end

:usage
echo.
echo --- 用法提示 ---
echo.
echo Usage: build FILENAME (文件名不需要带 .asm 后缀)
echo Example: build hello
echo.
goto end

:end