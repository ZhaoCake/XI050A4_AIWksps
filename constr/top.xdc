# =============================================================================
# Colorlight i9+ v6.1 (XI050AB) -- pin constraints
# This file constrains only the ports used by the template top module.
# Append new ports here as the design grows.
# Full pin table: see reference/ (official example xdc + pinout doc).
# =============================================================================

# ---- Clock: 25MHz crystal (K4) ----
create_clock -period 40.000 -name clk_25m [get_ports i_clk_25m]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN K4} [get_ports i_clk_25m]

# ---- Expansion LEDs o_led[3:0] (official example: DDR2-SODIMM header IO) ----
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN N14} [get_ports {o_led[0]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN P15} [get_ports {o_led[1]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN P16} [get_ports {o_led[2]}]
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN R16} [get_ports {o_led[3]}]

# ---- Board LED D2 (A18) ----
set_property -dict {IOSTANDARD LVCMOS33 PACKAGE_PIN A18} [get_ports o_led_board]

# ---- SPI Flash config (used when programming .bin; SRAM download unaffected) ----
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property CONFIG_MODE SPIx1 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR NO [current_design]
