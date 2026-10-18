## Constraints for fir_uart_modes_top (Nexys A7-100T). Pins follow Digilent's master XDC.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports btn_rst]       ;# BTNC
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {sw_mode[0]}]  ;# SW0
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports {sw_mode[1]}]  ;# SW1
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports sw_bypass]     ;# SW2
set_property -dict { PACKAGE_PIN C4  IOSTANDARD LVCMOS33 } [get_ports uart_rx_in]
set_property -dict { PACKAGE_PIN D4  IOSTANDARD LVCMOS33 } [get_ports uart_tx_out]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
