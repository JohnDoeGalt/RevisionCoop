@echo off
rem Builds RevCoop.exe (32 bit, like the bundled steam_api.dll) with the MSVC build tools.
setlocal
cd /d "%~dp0"
set VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -property installationPath`) do set VS=%%i
if not exist "%VS%\VC\Auxiliary\Build\vcvarsall.bat" (echo MSVC build tools not found & exit /b 1)
call "%VS%\VC\Auxiliary\Build\vcvarsall.bat" x86 >nul
rem A window, no console (main() stays the entry point); the manifest gives modern controls.
rem "build.bat fake": RevCoopFake.exe, the test build with Steam faked (tools/run_relay_test.ps1).
set OUT=RevCoop.exe
set DEF=
if "%1"=="fake" (set OUT=RevCoopFake.exe& set DEF=/DREVCOOP_FAKE_STEAM)
cl /nologo /O2 /W3 /MT /D_CRT_SECURE_NO_WARNINGS %DEF% revcoop_relay.c /Fe:%OUT% ws2_32.lib user32.lib gdi32.lib comctl32.lib shell32.lib /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup /MANIFEST:EMBED
del /q revcoop_relay.obj 2>nul
