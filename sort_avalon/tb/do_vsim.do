vlib work

vlog -sv ../rtl/sort_avalon.sv
vlog -sv sort_avalon_tb.sv

vsim sort_avalon_tb
add log -r /*
add wave -r *
run -all