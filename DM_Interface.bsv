package DM_Interface;

import Def::*;
// import Parse_command::* ;
import FIFOF::* ;
import SpecialFIFOs:: *;
import Vector::* ;
import Control_Fabric_Defs::*;
import ClientServer::* ;
import GetPut:: *;

import AXI4_Types		:: *;
import AXI4_Fabric		:: *;


interface DM_Interface_IFC;
	interface Client#(Control_Fabric_Req,Control_Fabric_Rsp) debugger;
	method Action put(Bit#(32) c,Bit#(Dba_width) d,Bit#(2) n) ;
endinterface


module mkDM_Interface(DM_Interface_IFC);

// Parse_command_ifc handle <- mkParse_command ;

AXI4_Master_Xactor_IFC #(`Addr_width,`Reg_width,0) debugger_bus_master <- mkAXI4_Master_Xactor;

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
Reg#(Bit#(2)) read_i <- mkReg(0) ;
Reg#(Bit#(2)) read_f <- mkReg(0) ;
Reg#(Bit#(2)) read_c <- mkReg(0) ;
Reg#(Bit#(2)) read_pc <- mkReg(0) ;
Reg#(Bit#(2)) read_mem <- mkReg(0) ;
Reg#(Bit#(2)) write_i <- mkReg(0) ;
Reg#(Bit#(2)) write_f <- mkReg(0) ;
Reg#(Bit#(2)) write_c <- mkReg(0) ;
Reg#(Bit#(2)) write_pc <- mkReg(0) ;
Reg#(Bit#(2)) write_mem <- mkReg(0) ;
Reg#(Bit#(2)) reset <- mkReg(0) ;
Reg#(Bit#(2)) query_status <- mkReg(0) ;
Reg#(Bit#(3)) step <- mkReg(0) ;
Reg#(Bit#(2)) state <- mkReg(1) ;


rule rl_continuously_poll_CPU(state == 1 && dmstatus[9] == 0 && halt == 0);
	state <= 2;
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:ucsr_addr_cpu_stop_reason,word:0} ;
	q1.enq(x) ;
	$display($time,"Polling CPU..");
endrule

rule rl_continuously_recv_CPU_rsp(state == 2);
	let rsp = q2.first;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK) begin
		if(rsp.word == 'h6 && halt == 0)begin
			state <= 1 ;
		end
		else begin
			state <= 0;
		end
	end
endrule


// understand command from user 
rule rl_understand_cmd(halt == 0 && resume == 0 && read_i == 0 && read_f == 0 && read_c == 0 && read_pc == 0 && read_mem == 0 && write_i == 0 && write_f == 0 && write_c == 0 && write_pc == 0 && write_mem == 0 && reset == 0 && query_status == 0 && step == 0); // 1 operation at a time
	let inp = fifo_in.first; 
	let cmd = inp.cmd ;
	in <= inp ;
	Bit#(32) temp_dmcontrol = dmcontrol ;
	Bit#(32) temp_command = command ;	
		
	// halt
	if(cmd == 1) begin
		fifo_in.deq ;
		temp_dmcontrol[31] = 1 ; //set haltreq
		halt <= 1 ;
	end
	if(dmstatus[9] == 1 && cmd != 1) begin  // command is not halt and cpu is stopped
		fifo_in.deq ;
		//resume
		if(cmd == 2) begin
			temp_dmcontrol[30] = 1 ; //set resumereq 		
			resume <= 1 ;
		end
		//reset
		else if(cmd == 3)begin
			reset <= 1 ;
			temp_dmcontrol[29] = 1 ;
		end
		//step
		else if(cmd == 4)begin
			step <= 1 ;
		end

		// read register(igpr)
		else if(cmd == 5) begin
			read_i <= 1 ;
			$display($time,"readd");
		end
		//read reg(fgpr)
		else if(cmd == 6) begin
			read_f <= 1 ;
			$display($time,"readd");
		end
		//read reg(csr)
		else if(cmd == 7) begin
			read_c <= 1 ;
			$display($time,"readd");
		end
		// write reg(igpr)
		else if(cmd == 8) begin
			write_i <= 1 ;
			$display($time,"write");
		end
		// write reg(fgpr)
		else if(cmd == 9) begin
			write_f <= 1 ;
			$display($time,"write");
		end
		// write reg(csr)
		else if(cmd == 10) begin
			write_c <= 1 ;
			$display($time,"write");
		end
		// read reg(pc)
		else if(cmd == 11) begin
			read_pc <= 1 ;
			$display($time,"read");
		end
		// write reg(pc)
		else if(cmd == 12) begin
			write_pc <= 1 ;
			$display($time,"write");
		end

		// read memory
		else if(cmd == 13) begin
			read_mem <= 1 ;
			$display($time,"read memory");
		end
		// read memory
		else if(cmd == 14) begin
			write_mem <= 1 ;
			$display($time,"write memory");
		end
	end

	dmcontrol <= temp_dmcontrol ;
endrule

// Only 1 rule runs at a time as a command is being processed
(*mutually_exclusive = "rl_halt_req,rl_halt_rsp,rl_resume_req,rl_resume_rsp,rl_reset,rl_reset_rsp,rl_access_reg,rl_access_reg_rsp,rl_query_cpu_status,rl_get_cpu_status,rl_step_req,rl_step_rsp"*)

//Stop
rule rl_halt_req(halt == 1 && dmcontrol[31] == 1 && dmstatus[9] != 1); // haltreq reqd and not already halted
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;
	$display($time,"Halt request sent");
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
			$display($time,"CPU stop request acknowledged");						
			query_status <= 1 ;
			halt <= 3 ;
		end
	end
endrule


// Check cpu status 
rule rl_query_cpu_status(query_status == 1) ;
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:ucsr_addr_cpu_stop_reason,word:0} ;
	q1.enq(x) ;
	$display($time,"Querying CPU status");
	query_status <= 2; 
endrule

rule rl_get_cpu_status(query_status == 2);
	let rsp = q2.first ;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		if(rsp.word == 'h6)begin // 6 --> CPU_BUSY
			if(halt == 3 || step == 3) begin
				$display($time,"CPU Busy");			
				query_status <= 1 ;
			end
			else if(resume == 3) begin
				$display($time,"CPU resumed");
				query_status <= 0 ;
				dmstatus[17] <= 1 ; // resume acknowledged
				resume <= 0 ;
				state <= 1 ;
			end
		end
		else begin
			if(halt == 3 || step == 3) begin
				$display($time,"CPU Stopped");
				query_status <= 0 ;
				dmstatus[9] <= 1 ;
				if(halt==3)begin halt <= 0 ;end 
				if(step==3)begin step <= 0 ;end
			end
			else if(resume == 3) begin
				$display($time,"CPU in stop state");			
				query_status <= 1 ;	
			end		
		end
	end
	else begin
		$display($time,"error reading cpu status");				
	end
endrule


//Run Continue(Resume)
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
			$display($time,"CPU resume request acknowledged");
			resume <= 3 ;
			query_status <= 1 ; 
		end
	end
endrule


//Reset
rule rl_reset(reset == 1 && dmcontrol[29] == 1 && dmstatus[9] == 1); // CPU should be stopped before reset
	$display($time,"Resetting CPU");
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
			$display($time,"CPU reset.");
			reset <= 0 ;
			dmstatus[29] <= 0 ;
		end
	end
endrule


//Reg Access
rule rl_access_reg((read_i == 1 || read_f == 1 || read_c == 1 || read_pc == 1 || write_i == 1 || write_f == 1 || write_c == 1 || write_pc == 1) && dmstatus[9] == 1); // cpu should be stopped before access
	let i = in ;
	Control_Fabric_Req x ;
	x = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;
	if(read_i == 1 || read_f == 1 || read_c == 1 || read_pc == 1)begin
		x.op = CONTROL_FABRIC_OP_RD;
		x.word = 0;
		if(read_i == 1)begin
			x.addr = ucsr_addr_cpu_x0 + truncate(in.args[0]) ;
			read_i <= 2 ;
		end
		else if(read_f == 1) begin
			x.addr = ucsr_addr_cpu_f_x0 + truncate(in.args[0]) ;
			read_f <= 2 ;
		end
		else if(read_c == 1) begin
			x.addr = 'hA2 + truncate(in.args[0]) ;
			read_c <= 2 ;
		end
		else if(read_pc == 1) begin
			x.addr = ucsr_addr_cpu_PC ;
			read_c <= 2 ;
		end
		if(read_pc != 1) begin
			$display($time,"Request to read reg no. %d sent",in.args[0][15:0]);
		end
		else begin
			$display("Request to read pc sent");
		end
	end
	else begin
		x.op = CONTROL_FABRIC_OP_WR;
		x.word = i.args[1] ;
		if(write_i == 1)begin
			x.addr = ucsr_addr_cpu_x0 + truncate(in.args[0]) ;
			read_i <= 2 ;
		end
		else if(write_f == 1) begin
			x.addr = ucsr_addr_cpu_f_x0 + truncate(in.args[0]) ;
			write_f <= 2 ;
		end
		else if(write_c == 1) begin
			x.addr = 'hA2 + truncate(in.args[0]) ;
			write_c <= 2 ;
		end
		else if(write_pc == 1) begin
			x.addr = ucsr_addr_cpu_PC ;
			write_pc <= 2 ;
		end
		if(write_pc != 2)begin
			$display($time,"Request to write reg no. %d with value %d sent",in.args[0][15:0],in.args[1][31:0]);
		end
		else begin
			$display("Request to write pc with value %d sent",in.args[1][31:0]);
		end
	end
	q1.enq(x) ;
endrule

rule rl_access_reg_rsp( (read_i == 2 || read_f == 2 || read_c == 2 || read_pc == 2 || write_i == 2 || write_f == 2 || write_c == 2 || write_pc == 2) && dmstatus[9] == 1); // cpu should be stopped before access
	let rsp = q2.first ;q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		if(read_i == 2 || read_f == 2 || read_c == 2)begin
			$display($time,"Value of register is %d",rsp.word[31:0]);
			if(read_i == 2)begin read_i <= 0 ; end
			if(read_f == 2)begin read_f <= 0 ; end
			if(read_c == 2)begin read_c <= 0 ; end
			if(read_pc == 2)begin read_pc <= 0 ; end
		end
		else begin
			$display($time,"Register write request acknowledged");
			if(write_i == 2)begin write_i <= 0 ; end
			if(write_f == 2)begin write_f <= 0 ; end
			if(write_c == 2)begin write_c <= 0 ; end
			if(write_pc == 2)begin write_pc <= 0 ; end
		end
	end
endrule


//read memory
rule rl_access_mem(read_mem == 1 || write_mem == 1);	
	if(read_mem == 1) begin
		let req = AXI4_Rd_Addr {araddr: in.args[0] , arprot: 0, aruser: 0, arlen: `DCACHE_BLOCK_SIZE-1, arsize: zeroExtend(info.transfer_size), arburst: 'b01, arid:'d0,arregion:0, arlock: 0, arcache: 0, arqos:0} ;
		debugger_bus_master.i_rd_addr.enq(req) ;
		read_mem <= 2 ;
	end
	else begin
		let aw = AXI4_Wr_Addr {awaddr: info.address, awprot:0, awuser:0, awlen: info.burst_length-1, awsize: zeroExtend(info.transfer_size), awburst: 'b01, awid:'d1,awregion:0, awlock: 0, awcache: 0, awqos:0}; // arburst: 00-FIXED 01-INCR 10-WRAP
      let w  = AXI4_Wr_Data {wdata:  truncate(info.data_line), wstrb: write_strobe_generation(info.transfer_size) , wlast:False, wid:'d1};
      dmem_xactor.i_wr_addr.enq(aw);
      dmem_xactor.i_wr_data.enq(w);

	end
endrule


//Step
rule rl_step_req(step == 1 && dmstatus[9] == 1);
	Control_Fabric_Req x=? ;
	x.op = CONTROL_FABRIC_OP_WR ;
	x.addr = ucsr_addr_cpu_step ;
	x.word = 0 ;
	step <= 2 ;	
	q1.enq(x) ;
endrule

rule rl_step_rsp(step == 2 && dmstatus[9] == 1) ;
	let rsp = q2.first; q2.deq ;
	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
		dmstatus[9] <= 1 ;
		$display($time,"Step request acknowledged");
		step <= 3 ; query_status <= 1 ;
	end
endrule






//receiving input
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
// 		$display($time,"hey not there");
		
// 	end

// 	//soft-reset
// 	if (hartreset == 1) 						//Hart with hart ID hartsel is not currently harted
// 	begin	
// 		$display($time,"had");
// 		x.addr = 16'h1001 ;
// 		x.word = 0 ;
// 		x.op = CONTROL_FABRIC_OP_WR ;
// 	end


// 	Bit #(2) op=dba[1:0];
// 	if (op==0)
// 	begin
// 		$display($time,"Bhaad me jao");
// 	end
// 	if (op==1)
// 	begin
// 		 read_data_flag<=1;
// 		 ready_read<=0;
// 		 x.addr=dba[49:34] ;
// 		 x.op=CONTROL_FABRIC_OP_RD;
// 		 x.word=?;
// 		 $display($time,"asfaf");
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
// 	$display($time,"here");
// 	let dba <- handle1.get_arg();
// 	$display($time,"data taken");
	

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
// 		$display($time,"Read performed correctly");
// 	end
// 	else
// 	begin
// 		$display($time,"Error in read");
// 	end
// endrule


// rule rl_collect_resp ;
// 	let rsp = q2.first ;q2.deq ;
// 	Bit#(32) temp_dmstatus = dmstatus ;
// 	if(rsp.status == CONTROL_FABRIC_RSP_OK)begin
// 		if(rsp.word == extend(ucsr_addr_cpu_continue))begin
// 			$display($time,"CPU resumed.");
// 			temp_dmstatus[17] = 1 ;
// 		end		
// 		if(rsp.word == 'h1001)begin
// 			$display($time,"CPU reset.");			
// 		end
// 	end
// 	// else begin
// 	// 	$display($time,"Error response from CPU");
// 	// end  
// 	dmstatus <= temp_dmstatus ;
// endrule

// rule rl_print(flag == 1) ;
// 	$display($time,"%d",dmcontrol);
// 	flag <= 0 ;
// 	// $finish;
// endrule

interface Client debugger ;
	interface Get request = toGet(q1) ;
	interface Put response = toPut(q2);		
endinterface

endmodule 

endpackage
