## spikesort.xdc
## Basys3 rev B — SpikeSort project constraints
## Modified from Basys3_Master.xdc
##
## Port mapping to spike_sorter_top.v:
##   clk       -> W5   (100 MHz onboard oscillator)
##   btnC      -> U18  (center button, active-high reset)
##   vp_in     -> J3   (JXADC XA1_P, VAUXP[0], analog positive)
##   vn_in     -> K3   (JXADC XA1_N, VAUXN[0], analog reference)
##   led[0:4]  -> U16, E19, U19, V19, W18
##   seg[0:6]  -> W7, W6, U8, V8, U5, V5, U7
##   an[0:3]   -> U2, U4, V4, W4

## Clock
set_property PACKAGE_PIN W5 [get_ports clk]
	set_property IOSTANDARD LVCMOS33 [get_ports clk]
	create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset button (center, active high)
set_property PACKAGE_PIN U18 [get_ports btnC]
	set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## JXADC analog input
## IOSTANDARD must be ANALOG for XADC dedicated pins - do NOT use LVCMOS33
set_property PACKAGE_PIN J3 [get_ports vp_in]
	set_property IOSTANDARD ANALOG [get_ports vp_in]
set_property PACKAGE_PIN K3 [get_ports vn_in]
	set_property IOSTANDARD ANALOG [get_ports vn_in]

## LEDs
## led[0:2] = live SNN output spikes (Neuron A, B, Noise)
## led[3:4] = latched classification code
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]

## 7-segment display segments (active low)
## seg[0]=a  seg[1]=b  seg[2]=c  seg[3]=d  seg[4]=e  seg[5]=f  seg[6]=g
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

## 7-segment anodes (active low)
## an[0] = rightmost digit (only digit active: RTL drives an = 4'b1110)
set_property PACKAGE_PIN U2 [get_ports {an[0]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]
	set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]
