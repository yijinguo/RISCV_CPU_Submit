//[3]=0 instruction. [2]: jump:1; branch:2; load:3; store:4; expri:5; expr:6
`define     LUI     11'b0110111

`define     AUIPC   11'b0010111

`define     JAL     11'b1101111
`define     JALR    11'b1100111
`define     BEQ     11'b000_1100011
`define     BNE     11'b001_1100011
`define     BLT     11'b100_1100011
`define     BGE     11'b101_1100011
`define     BLTU    11'b110_1100011
`define     BGEU    11'b111_1100011

`define     LB      11'b000_0000011 
`define     LH      11'b001_0000011
`define     LW      11'b010_0000011 
`define     LBU     11'b100_0000011
`define     LHU     11'b101_0000011 

`define     SB      11'b000_0100011 
`define     SH      11'b001_0100011
`define     SW      11'b010_0100011

`define     ADDI    11'b000_0010011
`define     SLTI    11'b010_0010011
`define     SLTIU   11'b011_0010011
`define     XORI    11'b100_0010011
`define     ORI     11'b110_0010011
`define     ANDI    11'b111_0010011
`define     SLLI    11'b0_001_0010011
`define     SRLI    11'b0_101_0010011
`define     SRAI    11'b1_101_0010011

`define     ADD     11'b0_000_0110011
`define     SUB     11'b1_000_0110011
`define     SLL     11'b0_001_0110011
`define     SLT     11'b0_010_0110011
`define     SLTU    11'b0_011_0110011
`define     XOR     11'b0_100_0110011
`define     SRL     11'b0_101_0110011
`define     SRA     11'b1_101_0110011
`define     OR      11'b0_110_0110011
`define     AND     11'b0_111_0110011

//[3]=1 operand.
`define     Add     4'd0 //+
`define     Sub     4'd1 //-
`define     Or      4'd2 //|
`define     Xor     4'd13 //^    
`define     And     4'd4  
`define     Lshift  4'd5 //<<
`define     Rshift  4'd6 //>>
`define     Lthan   4'd7 //<
`define     Lequal  4'd8 //<=
`define     Rthan   4'd9 //>
`define     Requal  4'd10 //>=
`define     Equal   4'd11 //==
`define     Nequal  4'd12 //!=