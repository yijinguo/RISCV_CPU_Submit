//instructions in reservation station, [2]=0,5,6

`include "define.v"

module rs #(
    parameter RS_SIZE = 10 //need to modify
)(
    input   wire            clk_in,
    input   wire            rst_in,
    input   wire            rdy_in,
    input   wire            clear,

    input   wire            from_rob, //1: rob has instr input
    input   wire [ 4:0]     entry_in,
    input   wire [10:0]     opcode_in,
    input   wire [31:0]     pc_address_in,
    input   wire [ 4:0]     rs1_in,
    input   wire [ 4:0]     rs2_in,
    input   wire [31:0]     imm_in,

    input   wire            have_cdb_rs,
    input   wire [ 4:0]     entry_cdb_rs,           
    input   wire [ 4:0]     new_entry_cdb_rs,
    input   wire[31:0]      value_cdb_rs,
    input   wire            have_cdb_branch,
    input   wire [ 4:0]     entry_cdb_branch,        
    input   wire [ 4:0]     new_entry_cdb_branch,
    input   wire [31:0]     value_cdb_branch,
    input   wire            have_cdb_slb,
    input   wire [ 4:0]     entry_cdb_slb,          
    input   wire [ 4:0]     new_entry_cdb_slb,
    input   wire [31:0]     value_cdb_slb,
    
    output  wire            rs_full,

    output  wire            have_execute,
    output  wire [ 4:0]     entry_execute,
    output  wire [31:0]     result
);

reg [4:0] dest_entry[RS_SIZE-1:0];
reg [RS_SIZE-1:0] ready;
reg [10:0] opcode[RS_SIZE-1:0];
reg [31:0] pc_address[RS_SIZE-1:0];
reg [31:0] vj[RS_SIZE-1:0], vk[RS_SIZE-1:0];
reg [ 4:0] qj[RS_SIZE-1:0];
reg [ 4:0] qk[RS_SIZE-1:0];
reg [31:0] imm[RS_SIZE-1:0]; 
integer rs_num;

reg rs_full_signal;
reg [3:0] op;
reg [31:0] op1, op2;
reg have_execute_signal;
reg [4:0] entry_execute_signal;

wire [4:0] qj0, qk0;
wire [31:0] vj0, vk0;

integer i,j;

assign rs_full = rs_full_signal;
assign have_execute = have_execute_signal;
assign entry_execute = entry_execute_signal;

regfile reg_query_1(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),
    .query      (1'b1),
    .reorder    (1'b0),
    .reorder_entry  (5'b0),
    .reorder_rd     (5'b0),
    .modify         (1'b0),
    .modify_entry   (5'b0),
    .modify_index   (rs1_in),
    .modify_value   (32'b0),

    .query_entry    (qj0),
    .query_value    (vj0)
);

regfile reg_query_2(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),
    .query      (1'b1),
    .reorder    (1'b0),
    .reorder_entry  (5'b0),
    .reorder_rd     (5'b0),
    .modify         (1'b0),
    .modify_entry   (5'b0),
    .modify_index   (rs2_in),
    .modify_value   (32'b0),

    .query_entry    (qk0),
    .query_value    (vk0)
);


always @(posedge clk_in)begin
    if (rst_in || clear) begin
        rs_num <= 0;
        ready <= 0;
        rs_full_signal <= 1'b0;
        have_execute_signal <= 1'b0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        rs_full_signal <= (rs_num == RS_SIZE - 2);

        //1.store the instruction from ROB;
        if (from_rob) begin
            dest_entry[rs_num] <= entry_in;
            opcode[rs_num] <= opcode_in;
            pc_address[rs_num] <= pc_address_in;
            imm[rs_num] <= imm_in;
            case (opcode_in[6:0])
                7'b0110111: begin
                    vj[rs_num] <= imm_in;
                    vk[rs_num] <= 32'b0;
                    qj[rs_num] <= 5'b0;
                    qk[rs_num] <= 5'b0;
                    ready[rs_num] <= 1'b1;
                end
                7'b0010111: begin
                    vj[rs_num] <= imm_in;
                    vk[rs_num] <= pc_address_in;
                    qj[rs_num] <= 5'b0;
                    qk[rs_num] <= 5'b0;
                    ready[rs_num] <= 1'b1;
                end
                7'b0010011: begin
                    if (qj0 == 5'b0) begin
                        ready[rs_num] <= 1'b1;
                    end
                    else begin
                        ready[rs_num] <= 1'b0;
                    end
                    qj[rs_num] <= qj0;
                    qk[rs_num] <= 5'b0;
                    vj[rs_num] <= vj0;
                    vk[rs_num] <= imm_in;
                end
                7'b0110011: begin
                    qj[rs_num] <= qj0;
                    qk[rs_num] <= qk0;
                    vj[rs_num] <= vj0;
                    vk[rs_num] <= vk0;
                    if (qj0 == 5'b0 && qk0 == 5'b0) begin
                        ready[rs_num] <= 1'b1;
                    end
                    else begin
                        ready[rs_num] <= 1'b0;
                    end
                end
                default: ;
            endcase
            rs_num <= rs_num + 1;  
        end

        //2.recall the feedback from cdb;
        if (have_cdb_rs) begin
            for (i=0;i<rs_num;i=i+1) begin
                if (qj[i]==entry_cdb_rs) begin
                    qj[i] <= new_entry_cdb_rs;
                    vj[i] <= value_cdb_rs;
                end
                if (qk[i]==entry_cdb_rs) begin
                    qk[i] <= new_entry_cdb_rs;
                    vk[i] <= value_cdb_rs;
                end
                if ( (qj[i]==5'b0 || (qj[i]==entry_cdb_rs && new_entry_cdb_rs==5'b0)) 
                    && (qk[i]==5'b0 || (qk[i]==entry_cdb_rs && new_entry_cdb_rs==5'b0)) ) begin
                    ready[i] = 1'b1;
                end
            end
        end
        if (have_cdb_branch) begin
            for (i=0;i<rs_num;i=i+1) begin
                if (qj[i]==entry_cdb_branch) begin
                    qj[i] <= new_entry_cdb_branch;
                    vj[i] <= value_cdb_branch;
                end
                if (qk[i]==entry_cdb_branch) begin
                    qk[i] <= new_entry_cdb_branch;
                    vk[i] <= value_cdb_branch;
                end
                if ( (qj[i]==5'b0 || (qj[i]==entry_cdb_branch && new_entry_cdb_branch==5'b0)) 
                    && (qk[i]==5'b0 || (qk[i]==entry_cdb_branch && new_entry_cdb_branch==5'b0)) ) begin
                    ready[i] = 1'b1;
                end
            end
        end
        if (have_cdb_slb) begin
            for (i=0;i<rs_num;i=i+1) begin
                if (qj[i]==entry_cdb_slb) begin
                    qj[i] <= new_entry_cdb_slb;
                    vj[i] <= value_cdb_slb;
                end
                if (qk[i]==entry_cdb_slb) begin
                    qk[i] <= new_entry_cdb_slb; 
                    vk[i] <= value_cdb_slb;
                end
                if ( (qj[i]==5'b0 || (qj[i]==entry_cdb_slb && new_entry_cdb_slb==5'b0)) 
                    && (qk[i]==5'b0 || (qk[i]==entry_cdb_slb && new_entry_cdb_slb==5'b0)) ) begin
                    ready[i] = 1'b1;
                end
            end
        end

        //3.select the ready ones and excute it, push the exe to the alu;
        i = 0;
        while (!ready[i] && i<rs_num) i=i+1;
        have_execute_signal <= (i<rs_num);
        if (i<rs_num) begin
            entry_execute_signal <= (i<rs_num) ? dest_entry[i] : 5'b0;
            op1 <= vj[i];
            op2 <= vk[i];
            case (opcode[i])
                `AUIPC: op <= `Add;
                `ADDI: op <= `Add; 
                `SLTI: op <= `Lthan;
                `SLTIU: op <= `Lthan;
                `XORI: op <= `Xor;
                `ORI: op <= `Or;
                `ANDI: op <= `And;
                `SLLI: op <= `Lshift;
                `SRLI: op <= `Rshift;
                `SRAI: op <= `Rshift; 
                `ADD: op <= `Add;
                `SUB: op <= `Sub;
                `SLL: op <= `Lshift;
                `SLT: op <= `Lthan;
                `SLTU: op <= `Lthan;
                `XOR: op <= `Xor;
                `SRL: op <= ``Or;
                `SRA: op <= `Rshift;
                `OR: op <= `Or;
                `AND: op <= `And;
            default: ;
            endcase
        end
        for (j=i; j<rs_num; j=j+1) begin
            dest_entry[j] <= dest_entry[j+1];
            pc_address[j] <= pc_address[j+1];
            ready[j] <= ready[j+1];
            opcode[j] <= opcode[j+1];
            vj[j] <= vj[j+1];
            vk[j] <= vk[j+1];
            qj[j] <= qj[j+1];
            qk[j] <= qk[j+1];
            imm[j] <= imm[j+1];
        end
        rs_num <= rs_num-1;
    end
end

ALU alu_execute(
    .op1    (op1),
    .op2    (op2),
    .op     (op),
    .result (result)
);
    
endmodule




/*RS的工作
1.store the instruction from ROB;
2.recall the feedback from cdb (commit);
3.select the ready ones and execute it, push the result into cdb;
*/

/*
    struct ReservationStations{
        bool ready = false;
        int only_sl = 3;
        uint code = 0;
        CommandType op {};
        uint vj = 0, qj = 0;
        uint vk = 0, qk = 0;
        uint pc = 0;
        int dest = 0;
        uint A = 0x00000000;
    };
    */