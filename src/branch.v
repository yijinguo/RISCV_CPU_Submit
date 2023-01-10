`include "define.v"

module branch #(
    parameter BRANCH_SIZE = 10
)(
    input   wire            clk_in,
    input   wire            rst_in,
	input   wire		    rdy_in,

    //if rob have input
    input   wire            have_input,
    input   wire [ 4:0]     entry_input,
    input   wire [10:0]     opcode_input,
    input   wire [31:0]     pc_address_input,
    input   wire [ 4:0]     rs1_input,
    input   wire [ 4:0]     rs2_input,
    input   wire [31:0]     imm_input,
    //if cdb have update
    input   wire            have_cdb_rs,
    input   wire [ 4:0]     entry_cdb_rs,
    input   wire [ 4:0]     new_entry_cdb_rs,
    input   wire [31:0]     value_cdb_rs,
    input   wire            have_cdb_branch,
    input   wire [ 4:0]     entry_cdb_branch,
    input   wire [ 4:0]     new_entry_cdb_branch,
    input   wire [31:0]     value_cdb_branch,
    input   wire            have_cdb_slb,
    input   wire [ 4:0]     entry_cdb_slb,
    input   wire [ 4:0]     new_entry_cdb_slb,
    input   wire [31:0]     value_cdb_slb,

    //if have output: to cdb
    output  wire            have_out,
    output  wire [ 4:0]     entry_out,
    output  wire            if_pc_change_out,
    output  wire [31:0]     new_pc_address_out,
    output  wire [31:0]     value_out
);


reg [10:0] opcode[BRANCH_SIZE-1:0];
reg [31:0] pc_address[BRANCH_SIZE-1:0];
reg [ 4:0] entry[BRANCH_SIZE-1:0];
reg [BRANCH_SIZE-1:0] ready;
reg [31:0] vj[BRANCH_SIZE-1:0], vk[BRANCH_SIZE-1:0];
reg [4:0] qj[BRANCH_SIZE-1:0], qk[BRANCH_SIZE-1:0];
reg [31:0] imm[BRANCH_SIZE-1:0]; 
integer branch_num = 0;

reg br_have_out;
reg [ 4:0] br_entry_out;
reg br_if_pc_c_out;
reg [31:0] br_new_pc_a_out;
reg [31:0] br_value_out;

wire [ 4:0] qj0, qk0;
wire [31:0] vj0, vk0;

integer i, j;

assign have_out = br_have_out;
assign entry_out = br_have_out;
assign if_pc_change_out = br_if_pc_c_out;
assign new_pc_address_out = br_new_pc_a_out;
assign value_out = br_value_out;

regfile reg_query_1(
    .clk_in         (clk_in),
    .rst_in         (rst_in),
    .rdy_in         (rdy_in),
    .query          (1'b1),
    .reorder        (1'b0),
    .reorder_entry  (5'b0),
    .reorder_rd     (5'b0),
    .modify         (1'b0),
    .modify_entry   (5'b0),
    .modify_index   (rs1_input),
    .modify_value   (32'b0),

    .query_entry    (qj0),
    .query_value    (vj0)
);

regfile reg_query_2(
    .clk_in         (clk_in),
    .rst_in         (rst_in),
    .rdy_in         (rdy_in),
    .query          (1'b1),
    .reorder        (1'b0),
    .reorder_entry  (5'b0),
    .reorder_rd     (5'b0),
    .modify         (1'b0),
    .modify_entry   (5'b0),
    .modify_index   (rs2_input),
    .modify_value   (32'b0),

    .query_entry    (qk0),
    .query_value    (vk0)
);

always @(posedge clk_in) begin
    if (rst_in) begin
        branch_num <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        //rob have input
        if (have_input) begin
            branch_num <= branch_num + 1;
            opcode[branch_num] <= opcode_input;
            pc_address[branch_num] <= pc_address_input;
            entry[branch_num] <= entry_input;
            imm[branch_num] <= imm_input;
            case (opcode_input[6:0]) 
                7'b1101111: begin
                    ready[branch_num] <= 1'b1;
                    qj[branch_num] <= 5'b0;
                    qk[branch_num] <= 5'b0;
                    vj[branch_num] <= vj0;
                    vk[branch_num] <= vk0;
                end
                7'b1100111: begin
                    ready[branch_num] <= (qj0==5'b0);
                    qj[branch_num] <= qj0;
                    qk[branch_num] <= 5'b0;
                    vj[branch_num] <= vj0;
                    vk[branch_num] <= vk0;
                end
                7'b1100011: begin
                    qj[branch_num] <= qj0;
                    qk[branch_num] <= qk0;
                    vj[branch_num] <= vj0;
                    vk[branch_num] <= vk0;
                    ready[branch_num] <= (qj0==5'b0 && qk0==5'b0);
                end
                default: ;
            endcase
        end
        
        //if cdb have data
        if (have_cdb_rs) begin
            for (i=0;i<branch_num;i=i+1) begin
                if (qj[i]==entry_cdb_rs) begin
                    qj[i] <= new_entry_cdb_rs;
                    vj[i] <= value_cdb_rs;
                end
                if (qk[i]==entry_cdb_rs) begin
                    qk[i] <= new_entry_cdb_rs;
                    vk[i] <= value_cdb_rs;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_rs && new_entry_cdb_rs==0)) 
                && ( qk[i]==0 || (qk[i]==entry_cdb_rs && new_entry_cdb_rs==0)) ) begin
                    ready[i] <= 1'b1;
                end
            end
        end
        if (have_cdb_branch) begin
            for (i=0;i<branch_num;i=i+1) begin
                if (qj[i]==entry_cdb_branch) begin
                    qj[i] <= new_entry_cdb_branch;
                    vj[i] <= value_cdb_branch;
                end
                if (qk[i]==entry_cdb_branch) begin
                    qk[i] <= new_entry_cdb_branch;
                    vk[i] <= value_cdb_branch;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_branch && new_entry_cdb_branch==0)) 
                && ( qk[i]==0 || (qk[i]==entry_cdb_branch && new_entry_cdb_branch==0)) ) begin
                    ready[i] <= 1'b1;
                end
            end
        end
        if (have_cdb_slb) begin
            for (i=0;i<branch_num;i=i+1) begin
                if (qj[i]==entry_cdb_slb) begin
                    qj[i] <= new_entry_cdb_slb;
                    vj[i] <= value_cdb_slb;
                end
                if (qk[i]==entry_cdb_slb) begin
                    qk[i] <= new_entry_cdb_slb;
                    vk[i] <= value_cdb_slb;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_slb && new_entry_cdb_slb==0)) 
                && ( qk[i]==0 || (qk[i]==entry_cdb_slb && new_entry_cdb_slb==0)) ) begin
                    ready[i] <= 1'b1;
                end
            end
        end

        //push result into cdb
        i = 0;
        while (!ready[i] && i<branch_num) i=i+1;
        br_have_out <= (i<branch_num);
        if (i<branch_num) begin
            br_entry_out <= entry[i];
            case (opcode[i])
                `JAL: begin
                    br_value_out <= pc_address[i] + 4;
                    br_if_pc_c_out <= 1'b1;
                    br_new_pc_a_out <= pc_address[i] + imm[i];
                end
                `JALR: begin
                    br_value_out <= pc_address[i] + 4;
                    br_if_pc_c_out <= 1'b1;
                    br_new_pc_a_out <= vj[i] + imm[i];
                end
                `BEQ: begin
                    br_if_pc_c_out <= (vj[i]==vk[i]);
                    br_new_pc_a_out <= pc_address[i] + imm[i]; 
                end  
                `BNE: begin
                    br_if_pc_c_out <= (vj[i]!=vk[i]);
                    br_new_pc_a_out <= pc_address[i] + imm[i]; 
                end  
                `BLT: begin
                    br_if_pc_c_out <= (vj[i]<vk[i]);
                    br_new_pc_a_out <= pc_address[i] + imm[i]; 
                end    
                `BGE: begin
                    br_if_pc_c_out <= (vj[i]>=vk[i]);
                    br_new_pc_a_out <= pc_address[i] + imm[i]; 
                end   
                `BLTU: begin
                    br_if_pc_c_out <= (vj[i]<vk[i]);
                    br_new_pc_a_out <= pc_address[i] + imm[i]; 
                end
                `BGEU: begin
                    br_if_pc_c_out <= (vj[i]>=vk[i]);
                    br_new_pc_a_out <= pc_address[i] + imm[i]; 
                end
                default: ;
            endcase
        end
        for (j=i; j<branch_num-1; j=j+1) begin
            opcode[j]<=opcode[j+1];
            pc_address[j]<=pc_address[j+1];
            entry[j]<=entry[j+1];
            ready[j]<=ready[j+1];
            vj[j]<=vj[j+1];
            vk[j]<=vk[j+1];
            qj[j]<=qj[j+1];
            qk[j]<=qk[j+1];
            imm[j]<=imm[j+1];
        end
        branch_num <= branch_num-1;
    end
end

    
endmodule