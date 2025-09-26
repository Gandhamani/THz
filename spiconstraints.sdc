# ==========================
# Clock
# ==========================
# 50 MHz system clock on port clk (period 20 ns)
create_clock -name clk -period 20.000 [get_ports clk]

# Optional clock uncertainty (separate for setup/hold so both are reported)
# (Tune these to your board/PLL budget if needed)
set_clock_uncertainty -setup 0.10 [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]

# ==========================
# I/O Delays (relative to clk)
# ==========================
# Use both -max (latest) and -min (earliest) to get setup & hold checks.
# Adjust to match your board timing budget.

# Inputs (to the chip)
set_input_delay  -clock clk -max 2.00 [get_ports {PICO SCK CS CPHA CPOL rst data_in[*]}]
set_input_delay  -clock clk -min 0.50 [get_ports {PICO SCK CS CPHA CPOL rst data_in[*]}]

# Outputs (from the chip)
set_output_delay -clock clk -max 2.00 [get_ports {POCI data_out[*] parity_err sample_tick_dbg cs_rise_dbg}]
set_output_delay -clock clk -min 0.50 [get_ports {POCI data_out[*] parity_err sample_tick_dbg cs_rise_dbg}]

# ==========================
# Asynchronous Reset
# ==========================
# Prevent reset from showing up as a timed path.
set_false_path -from [get_ports rst]

# ==========================
# Basic Design Rule Constraints (optional)
# ==========================
# Max transition on all nets
set_max_transition 1.0 [current_design]

# Max fanout
set_max_fanout 10 [current_design]

# Max load per output (example 0.10 pF)
set_max_capacitance 0.10 [current_design]

# ==========================
# (Optional) I/O drive/load modeling
# ==========================
# set_driving_cell  -lib_cell <lib_buf> [get_ports {PICO SCK CS CPHA CPOL rst data_in[*]}]
# set_load 0.10 [get_ports {POCI data_out[*] parity_err sample_tick_dbg cs_rise_dbg}]
