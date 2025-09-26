# Units (optional but good practice)
set_units -time ns -capacitance pF -resistance ohm -voltage V -current mA

########################################
# 1) Clock
########################################
create_clock -name CLK -period 10.0 [get_ports clk]     ;# 100 MHz

# Clock quality margins
set_clock_uncertainty -setup 0.20  [get_clocks CLK]
set_clock_uncertainty -hold  0.05  [get_clocks CLK]
# (Optional) clock transition model
# set_clock_transition 0.10 [get_clocks CLK]

# Keep the clock net ideal during synthesis (optional)
set_ideal_network      [get_ports clk]
set_dont_touch_network [get_ports clk]

########################################
# 2) I/O timing (relative to CLK)
########################################
# Define I/O port sets
set in_ports  [remove_from_collection [all_inputs]  [get_ports {clk rst}]]
set out_ports [all_outputs]

# External device -> this block (arrival at input pins)
set_input_delay  -clock CLK -max 2.0  $in_ports
set_input_delay  -clock CLK -min 0.5  $in_ports

# This block -> external device (required at outputs)
set_output_delay -clock CLK -max 2.0  $out_ports
set_output_delay -clock CLK -min 0.5  $out_ports

# Model external drive and load
set_driving_cell -lib_cell INVX1 -pin Z $in_ports
set_load 0.10 $out_ports   ;# 0.10 pF (100 fF)

########################################
# 3) Special paths
########################################
# Asynchronous reset: don’t time it
set_false_path -from [get_ports rst]
# (Optional) assume reset deasserted for logic optimization
# set_case_analysis 0 [get_ports rst]

# DO NOT CUT clk->clk paths!  (This is what broke your timing.)
# REMOVE: set_false_path -from [get_clocks clk] -to [get_clocks clk]

########################################
# 4) (Optional) Path grouping – nicer reports
########################################
group_path -name IN2REG  -from $in_ports              -to   [all_registers]
group_path -name REG2OUT -from [all_registers]        -to   $out_ports
group_path -name REG2REG -from [all_registers -clock CLK] -to [all_registers -clock CLK]

########################################
# 5) Quick timing checks
########################################
check_timing
report_timing   -max_paths 10 -delay_type max
report_timing   -max_paths 10 -delay_type min
report_constraint -all_violators
