# ==========================
# Clock Constraint
# ==========================

# Define a 50MHz clock on SCL (20ns period)
create_clock -name scl -period 20.0 [get_ports scl]

# ==========================
# Input Delay Constraints
# ==========================

# Assuming input delay of 2ns from external source to the chip
set_input_delay 2.0 -clock scl [get_ports {scl rst_n slave_addr[*] data_in[*]}]

# ==========================
# Output Delay Constraints
# ==========================

# Assuming output delay of 2ns from the chip to external sink
set_output_delay 2.0 -clock scl [get_ports {sda data_out[*]}]

# ==========================
# Reset Constraints
# ==========================

# Asynchronous reset modeling
set_false_path -from [get_ports rst_n]

# ==========================
# Design Rule Constraints (optional)
# ==========================

# Maximum transition time (ns)
set_max_transition 1.0 [current_design]

# Maximum fanout
set_max_fanout 10 [current_design]

# Maximum load capacitance (pF)
set_max_capacitance 0.1 [current_design]
