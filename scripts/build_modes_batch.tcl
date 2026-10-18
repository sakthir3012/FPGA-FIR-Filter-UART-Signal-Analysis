# Command Prompt (after settings64.bat):  cd C:\Users\sakth\FIRFILTER  then
#   vivado -mode batch -source scripts\build_modes_batch.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir $root/bitstreams $root/reports
foreach f {fir_filter_32tap_modes uart_rx uart_tx fir_uart_modes_top} { read_verilog $root/rtl/$f.v }
read_xdc $root/constraints/nexys_a7_uart_modes.xdc
synth_design -top fir_uart_modes_top -part xc7a100tcsg324-1
opt_design
place_design
route_design
report_timing_summary -file $root/reports/modes_timing.rpt
report_utilization    -file $root/reports/modes_util.rpt
report_drc            -file $root/reports/modes_drc.rpt
puts "BOARD TIMING  MODES  WNS=[get_property SLACK [get_timing_paths -setup -max_paths 1]]  WHS=[get_property SLACK [get_timing_paths -hold -max_paths 1]]"
write_bitstream -force $root/bitstreams/fir_uart_modes.bit
puts "BITSTREAM: $root/bitstreams/fir_uart_modes.bit"
