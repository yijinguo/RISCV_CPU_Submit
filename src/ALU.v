`include "define.v"

module ALU (
    input   wire [31:0]     op1,
    input   wire [31:0]     op2,
    input   wire [ 3:0]     op,
    output  reg [31:0]      result
);

initial begin
    case (op)
        `Add: result <= op1 + op2;
        `Sub: result <= op1 - op2;
        `Or: result <= op1 | op2;
        `Xor: result <= op1 ^ op2;
        `Lshift: result <= op1 << op2;
        `Rshift: result <= op1 >> op2;
        `Lthan: result <= (op1 < op2) ? 32'b1 : 32'b0;
        `Lequal: result <= (op1 <= op2) ? 32'b1 : 32'b0;
        `Rthan: result <= (op1 > op2) ? 32'b1 : 32'b0;
        `Requal: result <= (op1 >= op2) ? 32'b1 : 32'b0;
    default: ;
    endcase
end

    
endmodule