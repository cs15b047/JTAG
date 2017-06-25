package DM_Interface;

import Def::*;
import Jtag::* ;
import FIFOF::* ;
import Vector::* ;

module mkDM_Interface(Empty);

Reg#(Bit#(32)) dmstatus <- mkReg(0) ;
Reg#(Bit#(32)) dmcontrol <- mkReg(0) ;
Reg#(Bit#(32)) hartinfo <- mkReg(0) ;
Reg#(Bit#(32)) abstractcs <- mkReg(0) ;
Reg#(Bit#(32)) command <- mkReg(0) ;

Reg#(Bit#(8)) rg_cmd <- mkReg(0) ;
Reg#(Bit#(Dba_width)) dba <- mkReg(0) ;

Reg#(Bit#(32)) flag <- mkReg(0) ;
Reg#(Bool) args_present <- mkReg(False) ;
Reg#(Bit#(32)) num_args <- mkReg(0) ;
Reg#(Bit#(32)) count <- mkReg(0) ;

//used for passing arguments and getting return values
Vector#(12,Reg#(Bit#(32))) data <- replicateM(mkReg(0)) ;


Jtag_IFC handle <- mkJtag ;

//understanding commands from user
//1. halt <hart_id> 2. resume <hart_id> 

//hart_id reqd for each?? 3. read <reg_num> 4. read <memory_locn> 5. step 6. break <pc/line_num>

FIFOF#(Bit#(32)) fifo_cmd <- mkFIFOF ;
FIFOF#(Bit#(32)) fifo_args <- mkFIFOF ;

rule rl_take_cmd ;
	let cmd_temp <- handle.get_cmd() ;
	fifo_cmd.enq(cmd_temp) ;
endrule

rule rl_understand_cmd(flag == 0);
	let cmd = fifo_cmd.first ; fifo_cmd.deq ;
	Bit#(32) temp_dmcontrol = dmcontrol ;
	Bit#(32) temp_command = command ;
	
	// assume nos. given above for code for commands 

	if(cmd[7:0] == 8'b00000001) // halt
	begin		
		rg_cmd <= 1 ;
		temp_dmcontrol[31] = 1 ; //set haltreq
		temp_dmcontrol[25:16] = cmd[17:8] ;//hart_id
		args_present <= False ;		
		num_args <= 0 ;
		flag <= 1 ;
	end
	else if(cmd[7:0] == 8'b00000010) //resume
	begin		
		rg_cmd <= 2 ;
		temp_dmcontrol[30] = 1 ; //set resumereq 
		temp_dmcontrol[25:16] = cmd[17:8] ; // hart_id
		args_present <= False ;
		num_args <= 0 ;
		flag <= 1 ;
	end
	else if(cmd[7:0] == 8'b00000011) // read register
	begin
		rg_cmd <= 3 ;
		temp_dmcontrol[25:16] = cmd[17:8] ; // hart_id
		args_present <= True ;
		num_args <= 1 ;
		count <= 0 ;
		flag <= 1 ;
	end
	else if(cmd[7:0] == 8'b00000100) // read memory
	begin
		rg_cmd <= 4 ;
		temp_dmcontrol[25:16] = cmd[17:8] ; // hart_id
		args_present <= True ;
		num_args <= 1 ;
		count <= 0 ;
		flag <= 1 ;
	end
	
	dmcontrol <= temp_dmcontrol ;
endrule

// run for times equal to no. of arguments 
rule rl_take_args(args_present == True && count < num_args && flag == 1) ;
	let temp <- handle.get_dba() ;
	dba <= temp ;
	Bit#(32) temp_command = command ;

	temp_command[15:0] = temp[49:34] ;
	if(temp[1:0] == 2'b10)
	begin
		data[count] <= temp[33:2] ;
	end
	command <= temp_command ;
	count <= count + 1 ;
endrule

rule rl_print(flag == 1 && count == num_args) ;
	$display("%d",dmcontrol);
	flag <= 0 ;
	$finish;

endrule

Reg #(Bit #(1) ) read_data_flag <- mkReg(0);
Reg #(Bit #(32) ) read_data <- mkReg(0);
Reg #(Bit #(1) ) ready_read <- mkReg(0);
Reg #(Bit #(16) ) address <- mkReg(0);
Reg #(Bit #(1) ) write_data_flag <- mkReg(0);


rule rl_dba_type(flag == 1 && args_present == True && count == num_args) ;
	Bit #(2) op=dba[1:0];
	if (op==0)
	begin
		$display("Bhaad me jao");
	end
	if (op==1)
	begin
		 address <= command[15:0] ;
		 read_data_flag<=1;
		 ready_read<=0;
	end
	if (op==2)
	begin		 
		 write_data_flag<=1;
		 address <= command[15:0] ;
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
	$finish;

endrule

//halt reset

rule rl_halt_or_reset;
	let haltreq = dmcontrol[31:31];
	let resumereq =dmcontrol[30:30];
	let hartreset = dmcontrol [29:29];
	let hasel = dmcontrol [26:26];
	let hartsel = dmcontrol [25:16];
	let ndmreset = dmcontrol [2:1];
	let dmactive =dmcontrol[0:0];

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

// rule rl_access_reg(cmd[7:0] == 8'b00000011 && flag == 1 && count == num_args ) ; //read reg
// 	$display("accessing reg_no. : %d",);
// endrule

endmodule 

// export dmstatus,dmcontrol,hartinfo,abstractcs,command,flag,args_present,num_args,data,fifo_cmd,fifo_args,rg_cmd,dba,flag;

endpackage