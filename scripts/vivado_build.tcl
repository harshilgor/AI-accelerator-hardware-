# Vivado batch synthesis + implementation + bitstream for Basys 3
# Usage: vivado -mode batch -source scripts/vivado_build.tcl

set proj_name "gpu_mac"
set proj_dir  [file normalize "../vivado_project"]
set rtl_dir   [file normalize "../rtl"]
set xdc_file  [file normalize "../constraints/basys3.xdc"]

set part "xc7a35tcpg236-1"

file mkdir $proj_dir
cd $proj_dir

create_project -force $proj_name $proj_dir -part $part

add_files [glob $rtl_dir/*.v]
set_property top basys3_top [current_fileset]

add_files -fileset constrs_1 $xdc_file

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed"
}

set bit_file [glob -nocomplain $proj_dir/$proj_name.runs/impl_1/*.bit]
puts ""
puts "=========================================="
puts " BUILD SUCCESS"
puts " Bitstream: $bit_file"
puts " Program Basys 3 in Vivado Hardware Manager"
puts "=========================================="
