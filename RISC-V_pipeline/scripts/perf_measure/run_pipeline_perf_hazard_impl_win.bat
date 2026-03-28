@echo off
setlocal

call "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -source "%~dp0run_pipeline_perf.tcl" -tclargs impl hazard

endlocal
