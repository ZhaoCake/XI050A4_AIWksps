@echo off
rem ===========================================================================
rem Board project command-line entry (cmd wrapper, forwards to build.ps1)
rem Usage: build.bat <target>    e.g. build.bat bitstream
rem ===========================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
exit /b %ERRORLEVEL%
