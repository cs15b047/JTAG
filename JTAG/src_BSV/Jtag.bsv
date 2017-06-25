package Jtag;

import Def::*;
import Clocks::*;
import StmtFSM::*;
import Utils::* ;
import FIFOF::* ;

interface Jtag_IFC;
	method ActionValue#(Bit#(Cmd_width)) get_cmd() ;
	method ActionValue#(Bit#(Dtmcs_width)) get_dtm() ;
	method ActionValue#(Bit#(Dba_width)) get_dba() ;
endinterface

module mkJtag(Jtag_IFC);

Clock clk <- exposeCurrentClock ; 
Clock inverted <- invertCurrentClock ;
	
//select input signal
	Reg#(Bit#(1)) tms <- mkRegU(clocked_by inverted); 
	Reg#(Bit#(32)) count_tms <- mkReg(0); 
	Reg#(Bit#(48)) tms_vec <- mkReg(48'b 011000000000000000000000000000000000111000000110) ;
	ReadOnly#(Bit#(1)) cross_tms <- mkNullCrossingWire(clk,tms);
	ReadOnly#(Bit#(32)) cross_count_tms <- mkNullCrossingWire(inverted,count_tms);
	ReadOnly#(Bit#(48)) cross_tms_vec <- mkNullCrossingWire(inverted,tms_vec);

// input output registers
	Reg#(Bit#(1)) tdi <- mkReg(0);
	Reg#(Bit#(32)) count_tdi <- mkReg(0) ;
	Reg#(Bit#(36)) tdi_vec <- mkReg(36'b 00000000000000000010000000011001) ;
	ReadOnly#(Bit#(1)) cross_tdi <- mkNullCrossingWire(clk,tdi);
	ReadOnly#(Bit#(32)) cross_count_tdi <- mkNullCrossingWire(inverted,count_tdi);
	ReadOnly#(Bit#(36)) cross_tdi_vec <- mkNullCrossingWire(inverted,tdi_vec);
	Reg#(Bit#(1)) tdo <-mkRegU(clocked_by inverted);
	ReadOnly#(Bit#(1)) cross_tdo <- mkNullCrossingWire(clk,tdo);

//Data Regs
		//shift reg
		Reg#(Bit#(Instr_width)) instruction <- mkReg(0) ;
		Reg #(Bit#(Dtmcs_width)) dtm_control <-mkReg(0);
		Reg#(Bit#(Dba_width)) dba <-mkReg(0) ;
		Reg#(Bit#(Cmd_width)) command <-mkReg(0) ;
		Reg#(Bit#(1)) bypass <- mkReg(0) ;
		Reg#(Bit#(32)) idcode <- mkReg(0) ;

		//latch reg
		Reg#(Bit#(Instr_width)) latch_ir <- mkRegU(clocked_by inverted) ;
		Reg #(Bit#(Dtmcs_width)) latch_dtm_control <-mkRegU(clocked_by inverted);
		Reg#(Bit#(Dba_width)) latch_dba <-mkRegU(clocked_by inverted) ;
		Reg#(Bit#(Cmd_width)) latch_command <-mkRegU(clocked_by inverted) ;
		Reg#(Bit#(1)) latch_bypass <- mkRegU(clocked_by inverted) ;
		Reg#(Bit#(32)) latch_idcode <- mkRegU(clocked_by inverted) ;

		//wires from latch to +ve
		ReadOnly#(Bit#(Dba_width)) cross_latch_dba<- mkNullCrossingWire(clk,latch_dba);
		ReadOnly#(Bit#(Cmd_width)) cross_latch_command <- mkNullCrossingWire(clk,latch_command);
		ReadOnly#(Bit#(Dtmcs_width)) cross_latch_dtm_control <- mkNullCrossingWire(clk,latch_dtm_control);
		ReadOnly#(Bit#(1)) cross_latch_bypass<- mkNullCrossingWire(clk,latch_bypass);
		ReadOnly#(Bit#(32)) cross_latch_idcode<- mkNullCrossingWire(clk,latch_idcode);	
		ReadOnly#(Bit#(Instr_width)) cross_latch_ir <- mkNullCrossingWire(clk,latch_ir);	

		//wires from shift reg to -ve
		ReadOnly#(Bit#(Dba_width)) cross_dba<- mkNullCrossingWire(inverted,dba);
		ReadOnly#(Bit#(Cmd_width)) cross_command<- mkNullCrossingWire(inverted,command);
		ReadOnly#(Bit#(Dtmcs_width)) cross_dtm_control<- mkNullCrossingWire(inverted,dtm_control);
		ReadOnly#(Bit#(1)) cross_bypass<- mkNullCrossingWire(inverted,bypass);
		ReadOnly#(Bit#(32)) cross_idcode<- mkNullCrossingWire(inverted,idcode);
		ReadOnly#(Bit#(Instr_width)) cross_instruction <- mkNullCrossingWire(inverted,instruction);	

//states of DFA
	Reg#(Bit#(1)) test_logic_reset <-mkReg(1) ;// state 1
	Reg#(Bit#(1)) run_test_idle <-mkReg(0) ;
	Reg#(Bit#(1)) select_dr_scan <-mkReg(0) ;
	Reg#(Bit#(1)) select_ir_scan <-mkReg(0) ;
	Reg#(Bit#(1)) capture_dr <-mkReg(0) ;
	Reg#(Bit#(1)) capture_ir <-mkReg(0) ;
	Reg#(Bit#(1)) shift_dr <-mkReg(0) ;
	Reg#(Bit#(1)) shift_ir <-mkReg(0) ;
	//ReadOnly#(Bit#(1)) w_shift_ir_crossed <- mkNullCrossingWire(inverted,shift_ir);	
	Reg#(Bit#(1)) shift_ir_neg <-mkRegU(clocked_by inverted) ;
	//ReadOnly#(Bit#(1)) w_shift_ir_neg_crossed <- mkNullCrossingWire(clk,shift_ir_neg);
	Reg#(Bit#(1)) exit1_dr <-mkReg(0) ;
	Reg#(Bit#(1)) exit1_ir <-mkReg(0) ;
	Reg#(Bit#(1)) pause_dr <-mkReg(0) ;
	Reg#(Bit#(1)) pause_ir <-mkReg(0) ;
	Reg#(Bit#(1)) exit2_dr <-mkReg(0) ;
	Reg#(Bit#(1)) exit2_ir <-mkReg(0) ;
	Reg#(Bit#(1)) update_dr <-mkReg(0) ;
	Reg#(Bit#(1)) update_ir <-mkReg(0) ; // state 16

	ReadOnly#(Bit#(1)) cross_update_dr <- mkNullCrossingWire(inverted,update_dr);	
	ReadOnly#(Bit#(1)) cross_update_ir <- mkNullCrossingWire(inverted,update_ir);
	ReadOnly#(Bit#(1)) cross_test_logic_reset <- mkNullCrossingWire(inverted,test_logic_reset);	
	ReadOnly#(Bit#(1)) cross_shift_dr <- mkNullCrossingWire(inverted,shift_dr);	
	ReadOnly#(Bit#(1)) cross_shift_ir <- mkNullCrossingWire(inverted,shift_ir);


Reg#(Bit#(1)) tdo_enable <-mkRegU(clocked_by inverted);

// shifted out output of registers
	Reg#(Bit#(1)) instr_tdo <- mkRegU(clocked_by inverted);
	Reg#(Bit#(1)) bypass_tdo <- mkRegU(clocked_by inverted) ;
	Reg#(Bit#(1)) idcode_tdo <- mkRegU(clocked_by inverted) ;
	Reg#(Bit#(1)) dtm_control_tdo <- mkRegU(clocked_by inverted) ;
	Reg#(Bit#(1)) dba_tdo <- mkRegU(clocked_by inverted) ;
	Reg#(Bit#(1)) command_tdo <- mkRegU(clocked_by inverted) ;


//registers


//select bits
	Reg#(Bit#(1)) idcode_select <- mkReg(0) ;
	Reg#(Bit#(1)) extest_select <- mkReg(0) ;
	Reg#(Bit#(1)) debug_select <- mkReg(0) ;
	Reg#(Bit#(1)) command_select <- mkReg(0) ;
	Reg#(Bit#(1)) sample_preload_select <- mkReg(0) ;
	Reg#(Bit#(1)) bypass_select <- mkReg(0) ;

//input buffers
	FIFOF#(Bit#(1)) fifo_bypass <- mkFIFOF ;
	FIFOF#(Bit#(Cmd_width)) fifo_cmd <- mkFIFOF ;
	FIFOF#(Bit#(Dba_width)) fifo_dba <- mkFIFOF;
	FIFOF#(Bit#(32)) fifo_idcode <- mkFIFOF;
	FIFOF#(Bit#(Dtmcs_width)) fifo_dtm <- mkFIFOF;

Reg#(Bit#(32)) state <-mkReg(0) ;

(* mutually_exclusive = "rl_state_1,rl_state_2,rl_state_3,rl_state_4,rl_state_5,rl_state_6,rl_state_7,rl_state_8,rl_state_9,rl_state_10,rl_state_11,rl_state_12,rl_state_13,rl_state_14,rl_state_15,rl_state_16" *)
//dfa

	rule rl_state_1(test_logic_reset == 1);
		if(cross_tms == 0)
		begin
			test_logic_reset <=0 ; run_test_idle <= 1 ;
		end	
	endrule

	rule rl_state_2(run_test_idle == 1);
		
		if(cross_tms == 1)
		begin
			run_test_idle <= 0 ; select_dr_scan <= 1; 
		end	
	endrule

	rule rl_state_3(select_dr_scan == 1);
		if(cross_tms == 1)
		begin
			select_dr_scan <= 0;select_ir_scan <= 1; 
		end
		else if (cross_tms==0)
		begin
			select_dr_scan <=0;capture_dr <= 1;
		end
	endrule

	rule rl_state_4(select_ir_scan == 1);
		if(cross_tms == 1)
		begin
			test_logic_reset <= 1; 
		end
		else if (cross_tms==0)
		begin
			capture_ir <= 1; 
		end
		select_ir_scan <= 0;
	endrule

	rule rl_state_5(capture_dr == 1);
		if(cross_tms == 1)
		begin
			exit1_dr <= 1; 
		end
		else if(cross_tms == 0)
		begin
			shift_dr <= 1; 
		end
		capture_dr <= 0;
	endrule

	rule rl_state_6(capture_ir == 1);
		if(cross_tms == 1)
		begin
			exit2_ir <= 1; 
		end
		else if(cross_tms == 0)
		begin
			shift_ir <= 1; 
		end
		capture_ir <= 0;
	endrule

	rule rl_state_7(shift_dr == 1);
		if(cross_tms == 1)
		begin
			shift_dr <= 0;exit1_dr <= 1; 
		end

	endrule

	rule rl_state_8(shift_ir == 1);
		if(cross_tms == 1)
		begin
			shift_ir <= 0;exit1_ir <= 1; 
		end

	endrule

	rule rl_state_9(exit1_dr == 1);
		if(cross_tms == 1)
		begin
			update_dr <= 1; 
		end
		else if(cross_tms == 0)
		begin
			pause_dr <= 1; 
		end
		exit1_dr<= 0;

	endrule

	rule rl_state_10(exit1_ir == 1);
		if(cross_tms == 1)
		begin
			update_ir <= 1; 
		end
		else if(cross_tms == 0)
		begin
			pause_ir <= 1; 
		end
		exit1_ir <= 0;

	endrule

	rule rl_state_11(pause_dr == 1);
		if(cross_tms == 1)
		begin
			pause_dr<= 0;exit2_dr <= 1; 
		end
		

	endrule

	rule rl_state_12(pause_ir == 1);
		if(cross_tms == 1)
		begin
			pause_ir<= 0;exit2_ir <= 1; 
		end
		

	endrule

	rule rl_state_13(exit2_ir == 1);
		if(cross_tms == 1)
		begin
			update_ir <= 1; 
		end
		else if(cross_tms == 0)
		begin
			shift_ir <= 1; 
		end
		exit2_ir <= 0;
	endrule

	rule rl_state_14(exit2_dr == 1);
		if(cross_tms == 1)
		begin
			update_dr <= 1; 
		end
		else if(cross_tms == 0)
		begin
			shift_dr <= 1; 
		end
		exit2_dr <= 0;

	endrule

	rule rl_state_15(update_dr == 1);
		if(cross_tms == 1)
		begin
			select_dr_scan <= 1; 
		end
		else if(cross_tms == 0)
		begin
			run_test_idle <= 1; 
		end
		update_dr <= 0;

	endrule
	rule rl_state_16(update_ir == 1);
		if(cross_tms == 1)
		begin
			select_dr_scan <= 1; 
		end
		else if(cross_tms == 0)
		begin
			run_test_idle <= 1; 
		end
		update_ir<= 0;

	endrule

rule rl_print_state1;
	$display("%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",test_logic_reset,run_test_idle,select_dr_scan,select_ir_scan,capture_dr,capture_ir,shift_dr,shift_ir,exit1_dr,exit1_ir,pause_dr,pause_ir,exit2_dr,exit2_ir,update_dr,update_ir) ;
	$display("%d %d %d %d %d",instruction,cross_latch_ir,bypass,dba,command,dtm_control);
	$display("%d %d",count_tdi,cross_tms);
endrule

// rule rl_print_state2;
// $display("%d %d %d %d %d",instr_tdo,dba_tdo,command_tdo,bypass_tdo,idcode_tdo);
// $display("%d",tdo);
// endrule

//shift ir or load with default val if in reset
rule rl_instruction;
	int l = fromInteger(valueof(Instr_width)) ;
	if(test_logic_reset == 1 || capture_ir == 1 || shift_ir == 1)
	begin
		Bit#(Instr_width) temp = 0 ;
		if(test_logic_reset == 1)
		begin
			temp =  0 ;
		end
		if(capture_ir == 1)
		begin
			temp = 5'b10101 ;
		end
		if(shift_ir == 1)
		begin
			Bit#(TSub#(Instr_width,1)) t;
			t = instruction[l-1:1] ;
			temp = {tdi,t} ;
		end		
		instruction <= temp ;
	end 
endrule

// runs in -ve edge
rule rl_update_ir;
	if(cross_test_logic_reset == 1 || cross_update_ir == 1)
	begin
		Bit#(Instr_width) temp= 0 ;
		if(cross_update_ir == 1)
		begin
			temp = cross_instruction ;
		end
		else if(cross_test_logic_reset == 1)
		begin
			temp = 10 ;//put random value at reset
		end
		latch_ir <= temp ;
	end
endrule

rule rl_data;
	if(test_logic_reset == 1 || capture_dr == 1 || shift_dr == 1)
	begin
		if (cross_latch_ir == fromInteger(valueof(CMD)) )
		begin
			Bit#(Cmd_width) temp_command =0 ;		
			if(test_logic_reset == 1)
			begin
				temp_command = 0 ;
			end
			if(capture_dr == 1)
			begin
				temp_command = cross_latch_command ;
			end
			if(shift_dr == 1)
			begin
				Bit#(TSub#(Cmd_width,1)) t;
				int cmd_width = fromInteger(valueof(Cmd_width)) ;
				t = command[cmd_width-1:1] ;
				temp_command = {tdi,t} ;
			end
			command <= temp_command ;
		end

		if (cross_latch_ir == fromInteger(valueof(DBA)) )
		begin
			int d = fromInteger(valueof(Dba_width)) ;
			Bit#(Dba_width) temp_dba =0 ;		
			if(test_logic_reset == 1)
			begin
				temp_dba = 0 ;
			end
			if(capture_dr == 1)
			begin
				temp_dba = cross_latch_dba ;
			end
			if(shift_dr == 1)
			begin
				Bit#(TSub#(Dba_width,1)) t;
				t = dba[d-1:1] ;
				temp_dba = {tdi,t} ;
			end
			dba <= temp_dba ;
		end

		if (cross_latch_ir == fromInteger(valueof(DTM)) )
		begin
			Bit#(Dtmcs_width) temp_dtm =0 ;
			if(test_logic_reset == 1)
			begin
				temp_dtm =  0 ;
			end
			if(capture_dr == 1)
			begin
				temp_dtm = cross_latch_dtm_control;
			end
			if(shift_dr == 1)
			begin
				Bit#(TSub#(Dtmcs_width,1)) t;
				int dt = fromInteger(valueof(Dtmcs_width)) ;
				t = dtm_control[dt-1:1] ;
				temp_dtm = {tdi,t} ;
			end
			dtm_control <= temp_dtm ;
		end

		if (cross_latch_ir == fromInteger(valueof(BYPASS)) )
		begin
			Bit#(1) temp_bypass =0 ;
			if(test_logic_reset == 1)
			begin
				temp_bypass =  0 ;
			end
			if(capture_dr == 1)
			begin
				temp_bypass = cross_latch_bypass;
			end
			if(shift_dr == 1)
			begin
				temp_bypass = tdi ;
			end
			bypass <= temp_bypass ;
		end

		if (cross_latch_ir == fromInteger(valueof(IDCODE)) )
		begin
			Bit#(32) temp_idcode =0 ;
			if(test_logic_reset == 1)
			begin
				temp_idcode =  0 ;
			end
			if(capture_dr == 1)
			begin
				temp_idcode = cross_latch_idcode;
			end
			if(shift_dr == 1)
			begin
				Bit#(31) t;
				t = idcode[31:1] ;
				temp_idcode = {tdi,t} ;
			end
			idcode <= temp_idcode ;
		end
	end
endrule

// runs in -ve edge
rule rl_update_data ;
	if(cross_update_dr == 1)
	begin
		if(latch_ir == fromInteger(valueof(CMD)) )
		begin
			latch_command <= cross_command ;
		end
		if(latch_ir == fromInteger(valueof(DBA)) )
		begin
			latch_dba <= cross_dba ;
		end
		if(latch_ir == fromInteger(valueof(DTM)) )
		begin
			latch_dtm_control <= cross_dtm_control ;
		end
		if(latch_ir == fromInteger(valueof(BYPASS)) )
		begin
			latch_bypass <= cross_bypass ;
		end
		if(latch_ir == fromInteger(valueof(IDCODE)) )
		begin
			latch_idcode <= cross_idcode ;
		end			
	end
endrule

rule rl_buffer1(update_dr == 1 && state == 0);
	state <= 1 ;
endrule

rule rl_buffer2(state == 1);
	state <= 2 ;
endrule

//shifting out output in -ve edge (?????????) (directly from ip to op)
rule rl_shift_out;
	instr_tdo <= cross_instruction[0] ;
	dba_tdo <= cross_dba[0] ;
	command_tdo <= cross_command[0] ;
	dtm_control_tdo <= cross_dtm_control[0] ;
	bypass_tdo <= cross_bypass[0] ;
	idcode_tdo <= cross_idcode[0] ;
	// $display("%d",cross_dba[0]);
endrule

// rule rl_process_instr;
// 	extest_select <= (latch_ir == `EXTEST)?(1):(0) ;	
// 	// debug_select <= (latch_ir == `DEBUG)?(1):(0) ;
// 	sample_preload_select <= (latch_ir == `SAMPLE_PRELOAD)?(1):(0) ;
// 	bypass_select <= ( (latch_ir != `EXTEST)  && (latch_ir != `SAMPLE_PRELOAD) )?(1):(0) ;
// endrule

rule rl_assign_op ;
	Bit#(1) ans=0;
	if(latch_ir == fromInteger(valueof(DBA)))
	begin
		ans = dba_tdo ;
		$display("hi");
	end

	else if(latch_ir == fromInteger(valueof(CMD)))
	begin
		ans = command_tdo ;
	end
	
	else if(latch_ir == fromInteger(valueof(DTM)))
	begin
		ans = dtm_control_tdo ;
	end
	
	else if(latch_ir == fromInteger(valueof(IDCODE)))
	begin
		ans = idcode_tdo ;
	end
	
	else
	begin
		ans = bypass_tdo ;
	end	
	tdo <= ans ;
endrule

//simulate
rule rl_tp(cross_count_tms < 48 ) ;
	tms <= cross_tms_vec[cross_count_tms] ;
endrule

rule rl_inc_count;
	count_tms <= count_tms + 1;
	if(shift_dr == 1 || shift_ir == 1)
	begin
		tdi <= tdi_vec[count_tdi] ;
		count_tdi <= count_tdi + 1 ;
	end
endrule

// rule rl_stop(count_tms == 48);
// 	$finish ;
// endrule


// give input to DMInerface
method ActionValue#(Bit#(Cmd_width)) get_cmd() if(cross_latch_ir == fromInteger(valueof(CMD)) && state == 2);
	state <= 0;
	return cross_latch_command ;
endmethod
method ActionValue#(Bit#(Dtmcs_width)) get_dtm() if(cross_latch_ir == fromInteger(valueof(DTM)) && state == 2);
	state <= 0;
	return cross_latch_dtm_control ;
endmethod
method ActionValue#(Bit#(Dba_width)) get_dba() if(cross_latch_ir == fromInteger(valueof(DBA)) && state == 2);
	state <= 0;
	return cross_latch_dba ;
endmethod



endmodule
endpackage
