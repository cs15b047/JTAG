package Tb;

import Def::* ;
import Debug_Module ::*;
import CPU::*;
import CPU_IFC::* ;
import Connectable::* ;
import axi4::*;

module mkTb(Empty);

Ifc_proc cpu <- mkproc() ;

Reg#(Bit#(2)) given1 <- mkReg(0) ;

rule rl_put_inp(given1 < 2);
if (given1==0)
begin
	Bit#(6) address = 'h10 ;
	Bit#(32) data =1 ;
	Bit#(5) high = 31;
	Bit#(5) low = 31;
	$display("Input given") ;

	cpu.put(address,data,high,low) ;	
	given1 <= given1+1 ;
end
else
begin
	Bit#(6) address = 'h10 ;
	Bit#(32) data =1 ;
	Bit#(5) high = 30;
	Bit#(5) low = 30;
	$display("Input given") ;

	cpu.put(address,data,high,low) ;	
	given1 <= given1+1 ;
end
endrule

endmodule // mkTb

endpackage