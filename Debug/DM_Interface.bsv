package DM_Interface;

import Def::*;
// import Parse_command::* ;
import FIFOF::* ;
import SpecialFIFOs:: *;
import Vector::* ;
import Control_Fabric_Defs::*;
import ClientServer::* ;
import GetPut:: *;

interface DM_Interface_IFC;
	interface Client#(Control_Fabric_Req,Control_Fabric_Rsp) debugger;
	method Action put(Bit#(32) c,Bit#(Dba_width) d,Bit#(2) n) ;
endinterface


module mkDM_Interface(DM_Interface_IFC);

// Parse_command_ifc handle <- mkParse_command ;

Reg#(Bit#(32)) dmstatus <- mkReg(0) ;
Reg#(Bit#(32)) dmcontrol <- mkReg(0) ;
Reg#(Bit#(32)) hartinfo <- mkReg(0) ;
Reg#(Bit#(32)) abstractcs <- mkReg(0) ;
Reg#(Bit#(32)) command <- mkReg(0) ;
//used for passing arguments and getting return values
Vector#(12,Reg#(Bit#(32))) data <- replicateM(mkReg(0)) ;
Reg#(Bit#(16)) cmd <- mkReg(0) ;
Reg#(Bit#(Dba_width)) dba <- mkReg(0) ;

Reg#(Bit#(32)) flag <- mkReg(0) ;
Reg#(Bit#(32)) num_args <- mkReg(0) ;
Reg#(Bit#(32)) count <- mkReg(0) ;
Reg#(Bool) take_args <- mkReg(False) ;

FIFOF#(Control_Fabric_Req) q1 <- mkPipelineFIFOF ;
FIFOF#(Control_Fabric_Rsp) q2 <- mkPipelineFIFOF ;

FIFOF#(Input) fifo_in <- mkFIFOF ;
Reg#(Input) in <- mkReg(?) ;

Reg#(Bit#(2)) halt <- mkReg(0) ;
Reg#(Bit#(2)) resume <- mkReg(0) ;
Reg#(Bit#(2)) read <- mkReg(0) ;
Reg#(Bit#(2)) write <- mkReg(0) ;
Reg#(Bit#(2)) reset <- mkReg(0) ;
Reg#(Bit#(2)) query_status <- mkReg(0) ;


//understanding commands from user
//1. halt <hart_id> 2. resume <hart_id> 
//hart_id reqd for each?? 3. read <reg_num> 4. read <memory_locn> 5. step 6. break <pc/line_num>
//(*mutually_exclusive = "rl_understand_cmd,rl_dba_type"*)
rule rl_understand_cmd(halt == 0 && resume == 0 && read == 0 && write == 0 && reset == 0 && query_status == 0); // 1 operation at a time
	let inp = fifo_in.first; fifo_in.deq ;
	let cmd = inp.cmd ;
	in <= inp ;
	Bit#(32) temp_dmcontrol = dmcontrol ;
	Bit#(32) temp_command = command ;	
		
	// halt
	if(cmd == 1) begin
		temp_dmcontrol[31] = 1 ; //set haltreq
		halt <= 1 ;
	end
	//resume
	else if(cmd == 2) begin
		temp_dmcontrol[30] = 1 ; //set resumereq 		
		resume <= 1 ;
	end
	// read register
	else if(cmd == 3) begin
		read <= 1 ;
		$display("readd");
	end
	// write reg
	else if(cmd == 4) begin
		write <= 1 ;
		$display("write");
	end

	else if(cmd == 5)begin
		reset <= 1 ;
		temp_dmcontrol[29] = 1 ;
	end

	dmcontrol <= temp_dmcontrol ;
endrule

// rule tp;
// 	if(flag == 1 && take_args == True)
// 	begin $display("a"); end
// endrule

(*mutually_exclusive = "rl_halt_req,rl_halt_rsp,rl_resume_req,rl_resume_rsp,rl_reset,rl_reset_rsp,rl_access_reg,rl_access_reg_rsp,rl_query_cpu_status,rl_get_cpu_status"*)
rule rl_halt_req(halt == 1 && dmcontrol[31] == 1 && dmstatus[9] != 1); // haltreq reqd and not already halted
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;
	$display("Halt request sent");
	x.addr = ucsr_addr_cpu_stop ;
	x.op = CONTROL_FABRIC_OP_WR ;
	x.word = 0 ;
	dmcontrol[31] <= 0 ;
	q1.enq(x) ;
	halt <= 2 ;
endrule

rule rl_halt_rsp(halt == 2 && dmcontrol[31] == 0 && dmstatus[9] != 1) ;
	let rsp = q2.first ;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		if(rsp.word == extend(ucsr_addr_cpu_stop))begin
			$display("CPU stop request acknowledged");						
			query_status <= 1 ;
			halt <= 3 ;
		end
	end
	
endrule

rule rl_query_cpu_status(query_status == 1) ;
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:ucsr_addr_cpu_stop_reason,word:0} ;
	q1.enq(x) ;
	$display("Querying CPU status");
	query_status <= 2; 
endrule

rule rl_get_cpu_status(query_status == 2);
	let rsp = q2.first ;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		if(rsp.word == 'h6)begin // 6 --> CPU_BUSY
			$display("CPU Busy");			
			query_status <= 1 ;
		end
		else if(rsp.word == 'h5) begin
			$display("CPU Stopped");
			query_status <= 0 ;
			dmstatus[9] <= 1 ;
			halt <= 0 ;		
		end
	end
	else begin
		$display("CPU Stopped");
		query_status <= 0 ;
		dmstatus[9] <= 1 ;
		halt <= 0 ;		
	end
endrule

rule rl_resume_req(resume == 1 && dmcontrol[30] == 1 && dmstatus[9] == 1);
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;
	x.addr = ucsr_addr_cpu_continue ;
	x.op = CONTROL_FABRIC_OP_WR;
	x.word = 0;
	resume <= 2 ;
	q1.enq(x) ;
	dmcontrol[30] <= 0 ;
endrule

rule rl_resume_rsp(resume == 2 && dmcontrol[30] == 0 && dmstatus[9] == 1); // halted cpu
	let rsp = q2.first ;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		if(rsp.word == extend(ucsr_addr_cpu_continue))begin
			$display("CPU resume request acknowledged");
			resume <= 0 ;
			query_status <= 1 ; 
		end
	end
endrule

rule rl_reset(reset == 1 && dmcontrol[29] == 1 && dmstatus[9] == 1); // CPU should be stopped before reset
	$display("Resetting CPU");
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;
	x.addr = ucsr_addr_reset ;
	x.op = CONTROL_FABRIC_OP_WR;
	x.word = 0;
	reset <= 2 ;
	q1.enq(x) ;	
endrule

rule rl_reset_rsp(reset == 2 && dmcontrol[29] == 1 && dmstatus[9] == 1); // CPU should be stopped before reset
	let rsp = q2.first ;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		if(rsp.word == extend(ucsr_addr_reset))begin
			$display("CPU reset.");
			reset <= 0 ;
			dmstatus[29] <= 0 ;
		end
	end
endrule


rule rl_access_reg((read == 1 || write == 1) && dmstatus[9] == 1); // cpu should be stopped before access
	let i = in ;
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;
	if(read == 1)begin
		x.addr = ucsr_addr_cpu_x0 + truncate(in.args[0]) ;
		x.op = CONTROL_FABRIC_OP_RD;
		x.word = 0;
		read <= 2 ;
		$display("Request to read reg no. %d sent",in.args[0][15:0]);
	end
	else begin
		x.addr = ucsr_addr_cpu_x0 + truncate(in.args[0]) ;
		x.op = CONTROL_FABRIC_OP_WR;
		x.word = i.args[1] ;
		write <= 2 ;
		$display("Request to write reg no. %d with value %d sent",in.args[0][15:0],in.args[1][31:0]);
	end
	q1.enq(x) ;
endrule

rule rl_access_reg_rsp((read == 2 || write == 2) && dmstatus[9] == 1); // cpu should be stopped before access
	let rsp = q2.first ;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		if(read == 2)begin
			$display("Value of register is %d",rsp.word[31:0]);
			read <= 0 ;
		end
		else begin
			$display("Register write request acknowledged");
			write <= 0 ;
		end
	end
endrule








method Action put(Bit#(32) c,Bit#(Dba_width) d,Bit#(2) n) ;
	Input i =? ;
	i.cmd = truncate(c) ;
	if(n == 1)begin
		i.args[0] = extend(d[49:34]) ;
	end
	else if(n == 2)begin
		i.args[0] = extend(d[49:34]) ;
		i.args[1] = extend(d[33:2]) ;
	end
	i.num_args = n ;
	fifo_in.enq(i) ;
endmethod





//condition for rule : ((haltreq == 1 && dmstatus[9] != 1) || hartreset == 1 || resumereq == 1 || dba != 0)
// rule rl_halt_resume_reset;
// 	let haltreq = dmcontrol[31:31];
// 	let resumereq =dmcontrol[30:30];
// 	let hartreset = dmcontrol [29:29];
// 	let hasel = dmcontrol [26:26];
// 	let hartsel = dmcontrol [25:16];
// 	let ndmreset = dmcontrol [2:1];
// 	let dmactive =dmcontrol[0:0];

// 	Control_Fabric_Req x ;
// 	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;

// 	if (haltreq == 1 && dmstatus[9] != 1)	//&& isHartHalted(hartsel)==0		//Hart with hart ID hartsel is not currently harted
// 	begin
		
// 	end

// 	if (resumereq == 1 ) // && isHartHalted(hartsel)==1	//Hart with hart ID hartsel is not currently harted
// 	begin
// 		$display("hey not there");
		
// 	end

// 	//soft-reset
// 	if (hartreset == 1) 						//Hart with hart ID hartsel is not currently harted
// 	begin	
// 		$display("had");
// 		x.addr = 16'h1001 ;
// 		x.word = 0 ;
// 		x.op = CONTROL_FABRIC_OP_WR ;
// 	end


// 	Bit #(2) op=dba[1:0];
// 	if (op==0)
// 	begin
// 		$display("Bhaad me jao");
// 	end
// 	if (op==1)
// 	begin
// 		 read_data_flag<=1;
// 		 ready_read<=0;
// 		 x.addr=dba[49:34] ;
// 		 x.op=CONTROL_FABRIC_OP_RD;
// 		 x.word=?;
// 		 $display("asfaf");
// 		 dba <= 0 ; // reset dba		 
// 	end
// 	if (op==2)
// 	begin
// 		 data[0] <= dba[33:2];
// 		 write_data_flag<=1;
// 		 address<=dba[40:34];
// 	end

// 	q1.enq(x) ;

// endrule

// /*
// rule rl_dba_type(flag == 1 && take_args== True) ;
// 	$display("here");
// 	let dba <- handle1.get_arg();
// 	$display("data taken");
	

// endrule
// */

// rule rl_read_data(read_data_flag==1) ;
// 	//read_data<=cpu.get(address);
// 	let ans=q2.first;
// 	q2.deq ;
// 	read_data_flag<=0;
// 	if (ans.status==CONTROL_FABRIC_RSP_OK)
// 	begin
// 		handle.put(ans.word);
// 		ready_read<=1;
// 		$display("Read performed correctly");
// 	end
// 	else
// 	begin
// 		$display("Error in read");
// 	end
// endrule


// rule rl_collect_resp ;
// 	let rsp = q2.first ;q2.deq ;
// 	Bit#(32) temp_dmstatus = dmstatus ;
// 	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
// 		if(rsp.word == extend(ucsr_addr_cpu_continue))begin
// 			$display("CPU resumed.");
// 			temp_dmstatus[17] = 1 ;
// 		end		
// 		if(rsp.word == 'h1001)begin
// 			$display("CPU reset.");			
// 		end
// 	end
// 	// else begin
// 	// 	$display("Error response from CPU");
// 	// end  
// 	dmstatus <= temp_dmstatus ;
// endrule

// rule rl_print(flag == 1) ;
// 	$display("%d",dmcontrol);
// 	flag <= 0 ;
// 	// $finish;
// endrule

interface Client debugger ;
	interface Get request = toGet(q1) ;
	interface Put response = toPut(q2);		
endinterface

endmodule 

endpackage
