# Debug

Code runs in 2 clock domains - default and inverted clock, due to requirement by jtag to run certain operations at falling edge of clock.

DM_Interface : Debug Module
Tb : Testbench to drive inputs to debug module and connect it with cpu
