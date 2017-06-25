package Debug ;


import Jtag:: *;
import DM_Interface::*;
import Def::*;
import Clocks::*;
import StmtFSM::*;
import Utils::* ;


module mkDebug (Empty) ;
//Creg is the command register of 32 bit 
// Creg == 1 means halt   
Reg #(Bit #(1) ) read_data_flag <- mkReg(0);
Reg #(Bit #(32) ) read_data <- mkReg(0);
Reg #(Bit #(1) ) ready_read <- mkReg(0);
Reg #(Bit #(7) ) address <- mkReg(0);
Reg #(Bit #(1) ) write_data_flag <- mkReg(0);
Reg #(Bit #(32) ) data <- mkReg(0);
Reg #(Bit #(32) ) dm_control <- mkReg(0);



rule rl_dba_type(flag == 1 && args_present == True) ;
	Bit #(2) op=dba[1:0];
	if (op==0)
	begin
		$display("Bhaad me jao");
	end
	if (op==1)
	begin
		 address <= dba[40:34];
		 read_data_flag<=1;
		 ready_read<=0;
	end
	if (op==2)
	begin
		 data <= dba[33:2];
		 write_data_flag<=1;
		 address<=dba[40:34];
	end

endrule

rule rl_read_data(read_data_flag==1) ;
	// read_data<=cpu.get(address);
	read_data_flag<=0;
	ready_read<=1;
	$display("hi there");
endrule

rule rl_write_data(write_data_flag==1) ;
	// cpu.put(address,data);
	write_data_flag<=0;
	$display("hi not there");
endrule

//halt reset

rule rl_halt_or_reset;
	let haltreq = dm_control[31:31];
	let resumereq =dm_control[30:30];
	let hartreset = dm_control [29:29];
	let hasel = dm_control [26:26];
	let hartsel = dm_control [25:16];
	let ndmreset = dm_control [2:1];
	let dmactive =dm_control[0:0];

	if (haltreq == 1 )	//&& isHartHalted(hartsel)==0		//Hart with hart ID hartsel is not currently harted
	begin
		$display("hey there");
		// cpu_halt (hartsel) ;
		// isHartHalted (hartsel) = 1 ;
	end

	if (resumereq == 1 ) // && isHartHalted(hartsel)==1	//Hart with hart ID hartsel is not currently harted
	begin
		$display("hey not there");
		// cpu_resume (hartsel) ;
		// isHartHalted (hartsel) = 0 ;

	end

// 	if (haltreset == 1 ) 						//Hart with hart ID hartsel is not currently harted
// 	begin
// 		$display("had");
// // 		cpu_halt (hartsel) ;
// 		// TODO isHalted = ?  
// 	end

endrule

endmodule // mkDebug
endpackage : Debug

