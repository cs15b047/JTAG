package Def ;

import ISA_Decls::* ;
import Vector::* ;

typedef 4 EXTEST ;
typedef 2 SAMPLE_PRELOAD ;
typedef 31 BYPASS ;
typedef 17 DBA  ;
typedef 16 DTM ;
typedef 1 IDCODE ;
typedef 18 CMD ;

typedef 5 Instr_width;
typedef 50 Dba_width ; // address -->16 data -->32 op --> 2 dba_width=50
typedef 32 Cmd_width ;
typedef 32 Dtmcs_width ;

typedef struct {
	Bit#(16) cmd ;
	Vector#(3,Word) args ;
	Bit#(2) num_args ; 
} Input
deriving (Bits,FShow);


endpackage