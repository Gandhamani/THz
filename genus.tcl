
##############################################################################
#### Genus Synthesis Script for RAM (SG13G2 Technology)
##############################################################################

puts "Hostname : [info hostname]"

##############################################################################
## Preset global variables and attributes
##############################################################################

set DESIGN spi_top
set GEN_EFF medium
set MAP_OPT_EFF high
set DATE [clock format [clock seconds] -format "%b%d-%T"]
set _OUTPUTS_PATH outputs_${DATE}
set _REPORTS_PATH reports_${DATE}
set _LOG_PATH logs_${DATE}

# Technology library setup
set_db / .init_lib_search_path {/mcci2/terry/users/gandhamani.mohanraju/IHP-Open-PDK-main_1/IHP-Open-PDK-main/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib}
set_db / .init_hdl_search_path {/home/Docs1/gandhamani.mohanraju/linuxhome/verilog/SPIslaveParity}
set_db / .information_level 7

###############################################################
## Library setup
###############################################################

read_libs /mcci2/terry/users/gandhamani.mohanraju/IHP-Open-PDK-main_1/IHP-Open-PDK-main/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_slow_1p35V_125C.lib

set_db / .hdl_array_naming_style %s\[%d\]

################################################################################
## RTL Design Files
################################################################################

set_db hdl_max_memory_address_range 3456788900000
set_db hdl_max_loop_limit 40000


read_hdl -sv SPI_top.v
read_hdl -sv SPI_parity.v
read_hdl -sv SPIslave.v
elaborate $DESIGN
puts "Runtime & Memory after 'read_hdl'"
time_info Elaboration
check_design -unresolved

####################################################################
## Constraints Setup
####################################################################

read_sdc spi_constraints.sdc
puts "The number of exceptions is [llength [vfind "design:$DESIGN" -exception *]]"


# Create directories
foreach dir [list $_LOG_PATH $_OUTPUTS_PATH $_REPORTS_PATH] {
  if {![file exists $dir]} {
    file mkdir $dir
    puts "Creating directory $dir"
  }
}

report_timing -lint

###################################################################################
## Cost Groups (basic setup)
###################################################################################

if {[llength [all::all_seqs]] > 0} {
  define_cost_group -name I2C -design $DESIGN
  define_cost_group -name C2O -design $DESIGN
  define_cost_group -name C2C -design $DESIGN
  path_group -from [all::all_seqs] -to [all::all_seqs] -group C2C -name C2C
  path_group -from [all::all_seqs] -to [all::all_outs] -group C2O -name C2O
  path_group -from [all::all_inps] -to [all::all_seqs] -group I2C -name I2C
}
define_cost_group -name I2O -design $DESIGN
path_group -from [all::all_inps] -to [all::all_outs] -group I2O -name I2O

foreach cg [vfind / -cost_group *] {
  report_timing -cost_group [list $cg] >> $_REPORTS_PATH/${DESIGN}_pretim.rpt
}

####################################################################################################
## Synthesis Phases
####################################################################################################

# Generic
set_db / .syn_generic_effort $GEN_EFF
syn_generic
time_info GENERIC
report_dp > $_REPORTS_PATH/generic/${DESIGN}_datapath.rpt
write_snapshot -outdir $_REPORTS_PATH -tag generic
report_summary -directory $_REPORTS_PATH

# Mapping
set_db / .syn_map_effort $MAP_OPT_EFF
syn_map
time_info MAPPED
write_snapshot -outdir $_REPORTS_PATH -tag map
report_summary -directory $_REPORTS_PATH
report_dp > $_REPORTS_PATH/map/${DESIGN}_datapath.rpt

foreach cg [vfind / -cost_group *] {
  report_timing -cost_group [list $cg] > $_REPORTS_PATH/${DESIGN}_[vbasename $cg]_post_map.rpt
}

# Tie Cell Insertion (if needed, update cell names per library)
# add_tieoffs -high TIEHI -low TIELO -all -max_fanout 20 -verbose

# Optimization
set_db / .syn_opt_effort $MAP_OPT_EFF
syn_opt
write_snapshot -outdir $_REPORTS_PATH -tag syn_opt
report_summary -directory $_REPORTS_PATH
time_info OPT

foreach cg [vfind / -cost_group *] {
  report_timing -cost_group [list $cg] > $_REPORTS_PATH/${DESIGN}_[vbasename $cg]_post_opt.rpt
}

######################################################################################################
## Final Outputs
######################################################################################################

report_dp > $_REPORTS_PATH/${DESIGN}_datapath_incr.rpt
report_messages > $_REPORTS_PATH/${DESIGN}_messages.rpt
write_snapshot -outdir $_REPORTS_PATH -tag final
report_summary -directory $_REPORTS_PATH

write_sdc > ${_OUTPUTS_PATH}/${DESIGN}_m.sdc

# Flatten and export netlist/sdc for backend
ungroup -all -flatten
write_hdl > ./netlist/${DESIGN}.v
write_sdc > ./netlist/${DESIGN}.sdc

puts "Final Runtime & Memory."
time_info FINAL
puts "============================"
puts "Synthesis Finished ........."
puts "============================"

file copy [get_db / .stdout_log] ${_LOG_PATH}/.
