vlib work

vlog -sv ../rtl/fifo.sv
vlog -sv fifo_tb.sv

vsim -t 1ps -L altera_mf fifo_tb

add log -r /*
add wave -r *
run -all