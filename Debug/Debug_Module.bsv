package Debug_Module;

//import Def::*;
// import Parse_command::* ;
import FIFOF::* ;
import SpecialFIFOs:: *;
import Vector::* ;
import Control_Fabric_Defs::*;
import ClientServer::* ;
import GetPut:: *;


interface Debug_Module_IFC;
	interface Client#(Control_Fabric_Req,Control_Fabric_Rsp) debugger;
	method Action put  (Bit #(6) address,Bit # (32) data , Bit #(5) low ,Bit #(5) high ) ;
	//Read = 0 , Write = 1 
endinterface

module mkDebug_Module (Debug_Module_IFC) ;

FIFOF#(Control_Fabric_Req) request_to_cpu <- mkPipelineFIFOF ;
FIFOF#(Control_Fabric_Rsp) response_from_cpu <- mkPipelineFIFOF ;


//Registers from debug spec .13 start here 
Vector #( 12 , Reg#(Bit #(32))) abstract_Data <- replicateM(mkReg(0)) ;
Reg #(Bit #(32) ) debug_Module_Control <-mkReg (0) ;
Reg #(Bit #(32) ) debug_Module_Status <-mkReg (0) ;

//The registers after this line till next comment are for only such cases which have multiple harts
Reg #(Bit #(32) ) hart_Info <-mkReg (0) ;
Reg #(Bit #(32) ) hart_Summary <-mkReg (0) ;
Reg #(Bit #(32) ) hart_Array_Window_Select <-mkReg (0);
Reg #(Bit #(32) ) hart_Array_Window <-mkReg (0);
// Hart registers end here 
Reg #(Bit #(32) ) abstract_Control_And_Status <-mkReg (0) ;
Reg #(Bit #(32) )  abstract_Commands <-mkReg (0) ;
Reg #(Bit #(32) ) abstract_Command_Autoexe <-mkReg(0) ;
Reg #(Bit #(32) )  configuration_String_Addr_0<-mkReg (0) ;
Reg #(Bit #(32) )  configuration_String_Addr_1<-mkReg (0) ;
Reg #(Bit #(32) )  configuration_String_Addr_2<-mkReg (0) ;
Reg #(Bit #(32) )  configuration_String_Addr_3<-mkReg (0) ;
Vector #( 16 , Reg #(Bit #(32) )) program_Buffer <- replicateM(mkReg(0)) ;
Reg #(Bit #(32) )  authentication_Data <- mkReg (0) ;
Reg #(Bit #(32) )  serial_Control_And_Status <-mkReg (0) ;
Reg #(Bit #(32) )  serial_TX_Data <-mkReg (0) ;
Reg #(Bit #(32) )  serial_RX_Data <-mkReg (0) ;
Reg #(Bit #(32) )  system_Bus_Access_Control_And_Status <-mkReg (0) ;
Vector #( 3 , Reg #(Bit #(32) )) system_Bus_Address <- replicateM(mkReg(0)) ;
Vector #( 4 , Reg #(Bit #(32) )) system_Bus_Data <- replicateM(mkReg(0)) ;

Reg#(Bit#(32)) debug_control_and_status <- mkReg(0);
// Reg#(Bit#(XLEN)) debug_pc <-mkReg(0) ;
Reg#(Bit#(32)) debug_scratch_0 <- mkReg(0) ;
Reg#(Bit#(32)) debug_scratch_1 <- mkReg(0) ;

//Registers from debug spec .13 end here 

Reg #(Bit#(1)) continuously_query_cpu <-mkReg(0) ;

(*conflict_free = "halt,rl_query_cpu_status,response_collector,resume"*)

rule halt(debug_Module_Control[31]==1 && debug_Module_Status[9]==0);	
	Control_Fabric_Req request ;
	request = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:0,word:0} ;
	$display($time,"Halt request sent");
	request.addr = ucsr_addr_cpu_stop ;
	request.op = CONTROL_FABRIC_OP_WR ;
	request.word = 0 ;
	debug_Module_Control[31] <= 0 ;
	request_to_cpu.enq(request) ;	
	continuously_query_cpu <= 1;
endrule

// Check cpu status 
rule rl_query_cpu_status (continuously_query_cpu == 1) ;
	Control_Fabric_Req request ;
	request = Control_Fabric_Req{op:CONTROL_FABRIC_OP_RD,addr:ucsr_addr_cpu_stop_reason,word:0} ;
	request_to_cpu.enq(request) ;
	$display($time,"Querying CPU status");
endrule




rule response_collector ;
	let response=response_from_cpu.first;
	response_from_cpu.deq;
	$display($time,"CPU response : %d",response.word);
	if(response.word=='h5 && response.op == CONTROL_FABRIC_OP_RD && debug_Module_Status[9]==0 && response.status == CONTROL_FABRIC_RSP_OK)
	begin
		debug_Module_Status[9]<=1;
		$display($time,"Halted");
		continuously_query_cpu<=0;
	end
	if(response.word=='h6 && response.op == CONTROL_FABRIC_OP_RD&&debug_Module_Status[9]==1)
	begin
		debug_Module_Status[9]<=0;
		$display($time,"Resumed");
		continuously_query_cpu<=0;
	end
endrule

rule resume (debug_Module_Status[9]==1&&debug_Module_Control[30]==1);
	Control_Fabric_Req x=? ;
	x.addr = ucsr_addr_cpu_continue ;
	x.op = CONTROL_FABRIC_OP_WR;
	x.word = 0;
	request_to_cpu.enq(x) ;
	debug_Module_Control[30] <= 0 ;
	continuously_query_cpu<=1;
	$display("resume request sent");
endrule




method Action put  (Bit #(6) address,Bit # (32) data , Bit #(5) low ,Bit #(5) high ) ;
	$display("Input received");
	if (address <4)
	begin
		$display ("error in put 'address' argument");
	end
	if (address<=15)
	begin
		
		abstract_Data[address-4] <= data ;
	end
	if (address==16&&high==31)
	begin
		debug_Module_Control[31:31]<=truncate(data) ;
	end
	if (address==16&&high==30)
	begin
		debug_Module_Control[30:30]<=truncate(data) ;
	end

	/*if (address==17)
	begin
		debug_Module_Status[high:low]<=data ;
	end*/
	/*if (address==18)
	begin
		hart_Info[high:low]<=data ;
	end
	if (address==19)
	begin
		hart_Summary[high:low]<=data ;
	end
	if (address==20)
	begin
		hart_Array_Window_Select[high:low]<=data ;
	end
	if (address==21)
	begin
		hart_Array_Window[high:low]<=data ;
	end
	if(address==22)
	begin
		abstract_Control_And_Status[high:low]<=data;
	end
	if(address==23)
	begin
		abstract_Commands[high:low]<=data;
	end
	if(address==24)
	begin
		abstract_Command_Autoexe[high:low]<=data;
	end
	if (address==25)
	begin
		configuration_String_Addr_0[high:low]<=data ;
	end
	if (address==26)
	begin
		configuration_String_Addr_1[high:low]<=data ;
	end
	if(address==27)
	begin
		configuration_String_Addr_2[high:low]<=data;
	end
	if(address==28)
	begin
		configuration_String_Addr_3[high:low]<=data;
	end

	if(address>=32 && address<=47)
	begin
		program_Buffer[address-32][high:low]<=data;
	end
	if(address==48)
	begin
		authentication_Data[high:low]<=data;
	end
	if(address==52)
	begin
		serial_Control_And_Status[high:low]<=data;
	end
	if(address==53)
	begin
		serial_TX_Data[high:low]<=data;
	end
	if(address==54)
	begin
		serial_RX_Data[high:low]<=data;
	end
	if (address==56)
	begin
		system_Bus_Access_Control_And_Status[high:low]<=data ;
	end
	if(address<=57 && address<=59)
	begin
		system_Bus_Address[address-57][high:low]<=data;
	end
	if(address>=60 && address<64)
	begin
		system_Bus_Data[address-57][high:low]<=data;
	end*/
endmethod

interface Client debugger;
	interface Get request = toGet(request_to_cpu) ;
	interface Put response = toPut(response_from_cpu);	
endinterface


endmodule

endpackage 


























