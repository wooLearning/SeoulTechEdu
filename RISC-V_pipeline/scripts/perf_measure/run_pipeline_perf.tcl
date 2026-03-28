set script_dir    [file normalize [file dirname [info script]]]
set project_root  [file normalize [file join $script_dir ../..]]
set filelist_path [file join $script_dir filelists pipeline_sources.f]
set xdc_path      [file join $script_dir perf_clock.xdc]
set part_name     "xc7a35tcpg236-1"
set clk_period_ns 10.000

# Default to a post-route measurement because it is the more practical result.
set run_mode "impl"
set rom_variant "default"
if {[llength $argv] >= 1} {
  set run_mode [string tolower [lindex $argv 0]]
}
if {[llength $argv] >= 2} {
  set rom_variant [string tolower [lindex $argv 1]]
}

if {$run_mode ne "synth" && $run_mode ne "impl"} {
  puts "Usage: vivado -mode batch -source scripts/perf_measure/run_pipeline_perf.tcl -tclargs ?synth|impl? ?default|bubble|hazard|test2?"
  exit 1
}

if {$rom_variant ni [list "default" "bubble" "hazard" "test2"]} {
  puts "Usage: vivado -mode batch -source scripts/perf_measure/run_pipeline_perf.tcl -tclargs ?synth|impl? ?default|bubble|hazard|test2?"
  exit 1
}

proc load_source_list {project_root filelist_path} {
  set source_files {}
  set fp [open $filelist_path r]
  while {[gets $fp line] >= 0} {
    set trimmed [string trim $line]
    if {$trimmed eq ""} {
      continue
    }
    if {[string match "#*" $trimmed]} {
      continue
    }
    lappend source_files [file join $project_root $trimmed]
  }
  close $fp
  return $source_files
}

proc report_perf_summary {run_mode rom_variant report_dir clk_period_ns} {
  set worst_path [lindex [get_timing_paths -delay_type max -max_paths 1] 0]
  if {$worst_path eq ""} {
    puts [format "PERF_%s_%s no_timing_path_found" [string toupper $run_mode] [string toupper $rom_variant]]
    return
  }

  set slack_ns [get_property SLACK $worst_path]
  set delay_ns [expr {$clk_period_ns - $slack_ns}]
  if {$delay_ns <= 0.0} {
    set fmax_mhz 0.0
  } else {
    set fmax_mhz [expr {1000.0 / $delay_ns}]
  }

  set summary_path [file join $report_dir perf_summary.txt]
  set fp [open $summary_path w]
  puts $fp [format "mode=%s" $run_mode]
  puts $fp [format "rom_variant=%s" $rom_variant]
  puts $fp [format "clk_period_ns=%.3f" $clk_period_ns]
  puts $fp [format "slack_ns=%.3f" $slack_ns]
  puts $fp [format "delay_ns=%.3f" $delay_ns]
  puts $fp [format "fmax_mhz=%.3f" $fmax_mhz]
  close $fp

  puts [format "PERF_%s_%s delay_ns=%.3f slack_ns=%.3f fmax_mhz=%.3f" [string toupper $run_mode] [string toupper $rom_variant] $delay_ns $slack_ns $fmax_mhz]
}

set output_dir [file join $project_root output perf_measure $rom_variant $run_mode]
set report_dir [file join $output_dir reports]
file mkdir $report_dir

set rtl_files [load_source_list $project_root $filelist_path]

set synth_generic_args {}
set instr_mem_file [file join $project_root src mem InstructionDefault.mem]
switch -- $rom_variant {
  "bubble" {
    set instr_mem_file [file join $project_root src mem InstructionBubble.mem]
    set synth_generic_args [list -generic "P_USE_BUBBLE_ROM=1'b1" -generic "P_USE_HAZARD_ROM=1'b0" -generic "P_USE_TEST2_ROM=1'b0"]
  }
  "hazard" {
    set instr_mem_file [file join $project_root src mem InstructionHazard.mem]
    set synth_generic_args [list -generic "P_USE_BUBBLE_ROM=1'b0" -generic "P_USE_HAZARD_ROM=1'b1" -generic "P_USE_TEST2_ROM=1'b0"]
  }
  "test2" {
    set instr_mem_file [file join $project_root src mem InstructionFORTIMING.mem]
    set synth_generic_args [list -generic "P_USE_BUBBLE_ROM=1'b0" -generic "P_USE_HAZARD_ROM=1'b0" -generic "P_USE_TEST2_ROM=1'b1"]
  }
  default {
    set synth_generic_args [list -generic "P_USE_BUBBLE_ROM=1'b0" -generic "P_USE_HAZARD_ROM=1'b0" -generic "P_USE_TEST2_ROM=1'b0"]
  }
}

lappend synth_generic_args -generic "P_INSTR_MEM_FILE=$instr_mem_file"

read_verilog -sv $rtl_files
read_xdc $xdc_path

eval synth_design -top Top -part $part_name -mode out_of_context $synth_generic_args

if {$run_mode eq "impl"} {
  opt_design
  place_design
  phys_opt_design
  route_design
}

report_timing_summary -delay_type max -file [file join $report_dir timing_summary.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_perf_summary $run_mode $rom_variant $report_dir $clk_period_ns

if {$run_mode eq "impl"} {
  write_checkpoint -force [file join $output_dir top_routed.dcp]
}

exit
