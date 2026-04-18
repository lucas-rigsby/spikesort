## spikesort.xdc
## Basys-3 (xc7a35tcpg236-1) pin constraints for SpikeSort
## ──────────────────────────────────────────────────────────────────────────────

## ── System Clock ──────────────────────────────────────────────────────────────
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ── Reset Button (center, active high) ───────────────────────────────────────
set_property PACKAGE_PIN U18 [get_ports btnC]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## ── JXADC Analog Input ────────────────────────────────────────────────────────
## VAUXP[0] / VAUXN[0] — single-ended unipolar 0–1V input
## vp_in → J3 (positive)
## vn_in → K3 (reference / negative)
## External circuit: 100Ω series resistor + 10nF differential cap recommended
## DO NOT connect digital signals to these pins
set_property PACKAGE_PIN J3 [get_ports vp_in]
set_property IOSTANDARD ANALOG [get_ports vp_in]

set_property PACKAGE_PIN K3 [get_ports vn_in]
set_property IOSTANDARD ANALOG [get_ports vn_in]

## ── 7-Segment Display — Segments (active low) ────────────────────────────────
set_property PACKAGE_PIN W7  [get_ports {seg[0]}]
set_property PACKAGE_PIN W6  [get_ports {seg[1]}]
set_property PACKAGE_PIN U8  [get_ports {seg[2]}]
set_property PACKAGE_PIN V8  [get_ports {seg[3]}]
set_property PACKAGE_PIN U5  [get_ports {seg[4]}]
set_property PACKAGE_PIN V5  [get_ports {seg[5]}]
set_property PACKAGE_PIN U7  [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]

## ── 7-Segment Display — Anodes (active low) ──────────────────────────────────
set_property PACKAGE_PIN U2  [get_ports {an[0]}]
set_property PACKAGE_PIN U4  [get_ports {an[1]}]
set_property PACKAGE_PIN V4  [get_ports {an[2]}]
set_property PACKAGE_PIN W4  [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[*]}]

## ── LEDs ─────────────────────────────────────────────────────────────────────
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property PACKAGE_PIN V13 [get_ports {led[8]}]
set_property PACKAGE_PIN V3  [get_ports {led[9]}]
set_property PACKAGE_PIN W3  [get_ports {led[10]}]
set_property PACKAGE_PIN U3  [get_ports {led[11]}]
set_property PACKAGE_PIN P3  [get_ports {led[12]}]
set_property PACKAGE_PIN N3  [get_ports {led[13]}]
set_property PACKAGE_PIN P1  [get_ports {led[14]}]
set_property PACKAGE_PIN L1  [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
