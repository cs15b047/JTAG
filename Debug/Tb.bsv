package Tb;

import Def::* ;
import DM_Interface::*;
import CPU::*;
import CPU_IFC::* ;
import Connectable::* ;
import axi4::*;

module mkTb(Empty);

Ifc_proc cpu <- mkproc() ;

Reg#(Bit#(2)) given1 <- mkReg(0) ;

rule rl_put_inp(given1 < 2);
	Bit#(2) num_args = 0 ;
	Bit#(32) temp1 =0 ;
	if(given1 == 0)begin
		temp1 = 'h1 ;
		num_args = 0 ;
	end
	else if(given1 == 1)begin
		temp1 = 'h6 ;
		num_args = 1 ;
	end
	Bit#(Dba_width) temp2=0;
	if(num_args != 0) begin
		temp2[1:0] = 2'b01 ;
		temp2[49:34] = 16'h1 ;
		temp2[33:2] = 'h5 ;
	end
	cpu.put(temp1,temp2,num_args) ;
	given1 <= given1 + 1 ;	
	$display("%d",given1);	
endrule

endmodule // mkTb

endpackage