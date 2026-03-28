@echo off
setlocal

set SCRIPT_DIR=%~dp0
pushd "%SCRIPT_DIR%.."

py -3 tools\build_spike_artifacts.py %*
set EXIT_CODE=%ERRORLEVEL%

popd
exit /b %EXIT_CODE%
