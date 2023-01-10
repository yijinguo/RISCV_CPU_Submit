/*
In my design, Reorder Buffer is a queue of ROB_SIZE=10. 
A new instruction enters rob at tail. 
The entry will be added unitl it is equal ROB_SIZE and then reset it.
After an instruction is committed, the whole queue will be traersed and moved forward.
*/

`include "define.v"

module rob #(
    parameter ROB_SIZE = 20 //can be modified
)(
    input wire              clk_in,
    input wire              rst_in,
	input wire		        rdy_in,
    //if have instr input
    input wire              have_input,
    input wire [31:0]       instr_input,
    input wire [31:0]       instr_input_pc,
    input wire [16:0]       opcode_if,
    input wire [4:0]        rd_if,
    input wire [4:0]        rs1_if,
    input wire [4:0]        rs2_if,
    input wire [31:0]       imm_if,
    //if have cdb feedback
    input   wire            have_cdb_rs,
    input   wire [ 4:0]     entry_cdb_rs,
    input   wire [31:0]     value_cdb_rs,
    input   wire            have_cdb_branch,
    input   wire [ 4:0]     entry_cdb_branch,
    input   wire [31:0]     value_cdb_branch,
    input   wire            branch_if_pc_c,
    input   wire [31:0]     branch_new_pc_a,
    input   wire            have_cdb_slb,
    input   wire [ 4:0]     entry_cdb_slb,
    input   wire [31:0]     value_cdb_slb,

    //the result of dealing with cdb_feedback
    output  wire            have_rs_out,
    output  wire [ 4:0]     rd_cdb_rs,
    output  wire [ 4:0]     new_entry_cdb_rs,
    output  wire [ 4:0]     entry_rs,
    output  wire [31:0]     value_rs,
    output  wire            have_branch_out,
    output  wire [ 4:0]     rd_cdb_branch,
    output  wire [ 4:0]     new_entry_cdb_branch,
    output  wire [ 4:0]     entry_branch,
    output  wire [31:0]     value_branch,
    output  wire            if_pc_c_branch,
    output  wire [31:0]     new_pc_a_branch,
    output  wire            have_slb_out,
    output  wire [ 4:0]     rd_cdb_slb,
    output  wire [ 4:0]     new_entry_cdb_slb,
    output  wire [ 4:0]     entry_slb,
    output  wire [31:0]     value_slb,

    //if can output
    output wire             have_out,
    output wire             is_jump, //1 is jump
    output wire [ 1:0]      slb_or_rs_or_pc,  //0 arrive slb, 1 arrive rs, 2 arrive pc(branch)
    output wire [ 4:0]      entry_out,
    output wire [10:0]      opcode_out,
    output wire [31:0]      pc_address_out,
    output wire [ 4:0]      rd_out,
    output wire [ 4:0]      rs1_out,
    output wire [ 4:0]      rs2_out,
    output wire [31:0]      imm_out,
    //if need commit
    output wire             have_commit,
    output wire [ 4:0]      entry_commit,
    output wire [ 1:0]      destType_commit, //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
    output wire             if_pc_change_commit,
    output wire [31:0]      new_pc_address_commit,
    output wire [4:0]       destination_commit,
    output wire [31:0]      value_commit,

    output wire             rob_full   //1 if full    
);

reg[4:0] entry[ROB_SIZE-1:0]; 
reg[31:0] instr_origin[ROB_SIZE-1:0]; 
reg[ROB_SIZE-1:0] ready;
reg[1:0] destType[ROB_SIZE-1:0]; //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
reg[10:0] opcode[ROB_SIZE-1:0]; 
reg[4:0] destination[ROB_SIZE-1:0];
reg[31:0] value[ROB_SIZE-1:0];
reg[31:0] pc_value[ROB_SIZE-1:0]; 
reg[ROB_SIZE-1:0] pc_change; 

reg[4:0] rd[ROB_SIZE-1:0];
reg[4:0] rs1[ROB_SIZE-1:0], rs2[ROB_SIZE-1:0];
reg[31:0] imm[ROB_SIZE-1:0]; 

reg rob_full_signal;
integer rob_num; //the next index = the current number 
integer entry_num; //the next entry

integer i, j;

//对cdb的所有响应
reg rs_have_out;
reg [ 4:0] rs_rd;
reg [ 4:0] rs_entry;
reg [ 4:0] rs_new_entry;
reg [31:0] rs_value;
reg br_have_out;
reg [ 4:0] br_rd;
reg [ 4:0] br_entry;
reg [ 4:0] br_new_entry;
reg [31:0] br_value;
reg slb_have_out;
reg [ 4:0] slb_rd;
reg [ 4:0] slb_entry;
reg [ 4:0] slb_new_entry;
reg [31:0] slb_value;


assign have_rs_out = rs_have_out;
assign rd_cdb_rs = rs_rd;
assign new_entry_cdb_rs = rs_new_entry;
assign entry_rs = rs_entry;
assign value_rs = rs_value;
assign have_branch_out = br_have_out;
assign rd_cdb_branch = br_rd;
assign new_entry_cdb_branch = br_new_entry;
assign entry_branch = br_entry;
assign value_branch = br_value;
assign if_pc_c_branch = branch_if_pc_c;
assign new_pc_a_branch = branch_new_pc_a;
assign have_slb_out = slb_have_out;
assign rd_cdb_slb = slb_rd;
assign new_entry_cdb_slb = slb_new_entry;
assign entry_slb = slb_entry;
assign value_slb = slb_value;

assign rob_full = rob_full_signal;

//推入各部分的instr
reg have_instr_out;
reg instr_is_jump;
reg [ 1:0] instr_slb_rs_pc;
reg [ 4:0] instr_entry_out;
reg [10:0] instr_opcode_out;
reg [31:0] instr_pc_a_out;
reg [ 4:0] instr_rd_out;
reg [ 4:0] instr_rs1_out;
reg [ 4:0] instr_rs2_out;
reg [31:0] instr_imm_out;

assign have_out = have_instr_out;
assign is_jump = instr_is_jump;
assign slb_or_rs_or_pc = instr_slb_rs_pc;
assign entry_out = instr_entry_out;
assign opcode_out = instr_opcode_out;
assign pc_address_out = instr_pc_a_out;
assign rd_out = instr_rd_out;
assign rs1_out = instr_rs1_out;
assign rs2_out = instr_rs2_out;
assign imm_out = instr_imm_out;

//commit内容
reg rob_have_commit;
reg [ 4:0] rob_entry_commit;
reg [ 1:0] rob_destType_commit;
reg rob_if_pc_c_commit;
reg [31:0] rob_new_pc_a_commit;
reg [ 4:0] rob_destination_commit;
reg [31:0] rob_value_commit;

assign have_commit = rob_have_commit;
assign entry_commit = rob_entry_commit;
assign destType_commit = rob_destType_commit;
assign if_pc_change_commit = rob_if_pc_c_commit;
assign new_pc_address_commit = rob_new_pc_a_commit;
assign destination_commit = rob_destination_commit;
assign value_commit = rob_value_commit;


always @(posedge clk_in) begin
    if (rst_in) begin
        rob_num <= 0;
        entry_num <= 5'b0;
    end
    else if (!rdy_in) begin

    end
    else begin
        rob_full_signal <= (rob_num == ROB_SIZE - 2);
        
        //1.store the instruction from IF;
        if (have_input && rob_num < ROB_SIZE-1) begin
            rob_num <= rob_num + 1;
            entry_num <= (entry_num == ROB_SIZE) ? 1 : (entry_num + 1);
            entry[rob_num] <= entry_num;
            instr_origin[rob_num] <= instr_input;
            pc_value[rob_num] <= instr_input_pc;
            rd[rob_num] <= rd_if;
            rs1[rob_num] <= rs1_if;
            rs2[rob_num] <= rs2_if;
            imm[rob_num] <= imm_if;
            case (opcode_if[6:0])
                    7'b0110111: begin //LUI //rd, imm 
                        opcode[rob_num] <= `LUI;
                        destType[rob_num] <= 2'b01;
                        destination[rob_num] <= rd_if;
                        value[rob_num] <= imm_if;
                        ready[rob_num] <= 1'b1;
                    end
                    7'b0010111: begin //AUIPC //rd, imm
                        opcode[rob_num] <= `AUIPC;
                        destType[rob_num] <= 2'b01;
                        destination[rob_num] <= rd_if;
                        value[rob_num] <= instr_input_pc + imm_if;
                        ready[rob_num] <= 1'b1;
                    end
                    7'b1101111: begin //JAL //rd, imm
                        opcode[rob_num] <= `JAL;
                        destType[rob_num] <= 2'b11;
                        destination[rob_num] <= rd_if;
                        ready[rob_num] <= 1'b0;
                        pc_change[rob_num] <= 1'b1;
                    end
                    7'b1100111: begin//JALR //rd, rs1, imm
                        opcode[rob_num] <= `JALR;
                        destType[rob_num] <= 2'b11;
                        destination[rob_num] <= rd_if;
                        ready[rob_num] <= 1'b0;
                        pc_change[rob_num] <= 1'b1;
                    end
                    7'b1100011: begin //Branch //rs1, rs2, imm
                        destType[rob_num] <= 2'b10;
                        ready[rob_num] <= 1'b0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `BEQ;
                            3'b001: opcode[rob_num] <= `BNE;
                            3'b100: opcode[rob_num] <= `BLT;
                            3'b101: opcode[rob_num] <= `BGE;
                            3'b110: opcode[rob_num] <= `BLTU;
                            3'b111: opcode[rob_num] <= `BGEU;
                            default: opcode[rob_num] <= 11'b0;
                        endcase
                    end
                    7'b0000011: begin //Load //rd, rs1, imm
                        destType[rob_num] <= 2'b01;
                        destination[rob_num] <= rd_if;
                        ready[rob_num] <= 1'b0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `LB;
                            3'b001: opcode[rob_num] <= `LH;
                            3'b010: opcode[rob_num] <= `LW;
                            3'b100: opcode[rob_num] <= `LBU;
                            3'b101: opcode[rob_num] <= `LHU;
                            default: ; 
                        endcase
                    end
                    7'b0100011: begin //Store //rs1, rs2, imm
                        destType[rob_num] <= 2'b00;
                        ready[rob_num] <= 1'b0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `SB;
                            3'b001: opcode[rob_num] <= `SH;
                            3'b010: opcode[rob_num] <= `SW;
                            default: ;
                        endcase
                    end
                    7'b0010011: begin //expi //need rd, rs1, imm
                        destType[rob_num] <= 2'b01;
                        destination[rob_num] <= rd_if;
                        ready[rob_num] <= 1'b0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `ADDI;
                            3'b010: opcode[rob_num] <= `SLTI;
                            3'b011: opcode[rob_num] <= `SLTIU;
                            3'b100: opcode[rob_num] <= `XORI;
                            3'b110: opcode[rob_num] <= `ORI;
                            3'b111: opcode[rob_num] <= `ANDI;
                            3'b001: opcode[rob_num] <= `SLLI;
                            default:  //3'b101
                            case (opcode_if[16:10])
                                7'b0000000: opcode[rob_num] <= `SRLI;
                                7'b0100000: opcode[rob_num] <= `SRAI;
                                default: ;
                            endcase
                        endcase
                    end
                    7'b0110011: begin //exp //need rd, rs1, rs2
                        destType[rob_num] <= 2'b01;
                        destination[rob_num] <= rd_if;
                        ready[rob_num] <= 1'b0;
                        case (opcode_if[9:7])
                            3'b000: begin
                                case (opcode_if[16:10])
                                    7'b0000000: opcode[rob_num] <= `ADD;
                                    7'b0100000: opcode[rob_num] <= `SUB;
                                default: ;
                                endcase
                            end
                            3'b001: opcode[rob_num] <= `SLL;
                            3'b010: opcode[rob_num] <= `SLT;
                            3'b011: opcode[rob_num] <= `SLTU;
                            3'b100: opcode[rob_num] <= `XOR;
                            3'b101: begin
                                case (opcode_if[16:10])
                                    7'b0000000: opcode[rob_num] <= `SRL;
                                    7'b0100000: opcode[rob_num] <= `SRA;
                                    default: ;
                                endcase
                            end
                            3'b110: opcode[rob_num] <= `OR;
                            3'b111: opcode[rob_num] <= `AND;
                            default: ;
                        endcase
                    end
                    default: ; 
            endcase
        end 

        //2.fetch output
        //遍历ready，找到最上层的0(未被推入任何其他部件)，推入相应位置
        i = 0;
        while (ready[i] == 0 && i < rob_num) i=i+1;
        if (i < rob_num) begin
            have_instr_out <= 1'b1;
            instr_entry_out <= entry[i];
            instr_opcode_out <= opcode[i];
            instr_pc_a_out <= pc_value[i];
            instr_rd_out <= rd[i];
            instr_rs1_out <= rs1[i];
            instr_rs2_out <= rs2[i];
            instr_imm_out <= imm[i];
            case (opcode[i][6:0])
                7'b1101111:  begin //jal
                    instr_is_jump <= 1'b1; 
                    instr_slb_rs_pc <= 2'b10;
                end
                7'b1100111: begin //jalr
                    instr_is_jump <= 1'b1; 
                    instr_slb_rs_pc <= 2'b10;
                end
                7'b1100011: begin //branch
                    instr_is_jump <= 1'b0; 
                    instr_slb_rs_pc <= 2'b10;
                end
                7'b0000011: begin //load
                    instr_is_jump <= 1'b0; 
                    instr_slb_rs_pc <= 2'b00;
                end
                7'b0100011: begin //store
                    instr_is_jump <= 1'b0; 
                    instr_slb_rs_pc <= 2'b00;
                end
                default:  begin
                    instr_is_jump <= 1'b0; 
                    instr_slb_rs_pc <= 2'b01;
                end
            endcase
        end
        else begin
            have_instr_out <= 1'b0;
        end 

        //3.recall the feedback from cdb
        if (have_cdb_rs) begin
            rs_entry <= entry_cdb_rs;
            rs_value <= value_cdb_rs;
            i=0;
            while (i<rob_num && entry[i] != entry_cdb_rs) i=i+1;
            rs_rd <= destination[i];
            value[i] <= value_cdb_rs;
            ready[i] <= 1'b1;
            j=i+1;
            while (j<rob_num && destination[j]!=destination[i]) j=j+1;
            if (j<rob_num) begin
                rs_new_entry <= entry[j];
            end
            else begin
                rs_new_entry <= 5'b0;
            end
        end
        if (have_cdb_branch) begin
            br_entry <= entry_cdb_branch;
            br_value <= value_cdb_branch;
            i=0;
            while (i<rob_num && entry[i] != entry_cdb_branch) i=i+1;
            br_rd <= destination[i];
            value[i] <= value_cdb_branch;
            ready[i] <= 1'b1;
            pc_change[i] <= branch_if_pc_c;
            if (branch_if_pc_c) pc_value[i] <= branch_new_pc_a;
            j=i+1;
            while (j<rob_num && destination[j]!=destination[i]) j=j+1;
            if (j<rob_num) begin
                br_new_entry <= entry[j];
            end
            else begin
                br_new_entry <= 5'b0;
            end
        
        end
        if (have_cdb_slb) begin
            slb_entry <= entry_cdb_slb;
            slb_value <= value_cdb_slb;
            i=0;
            while (i<rob_num && entry[i] != entry_cdb_slb) i=i+1;
            slb_rd <= destination[i];
            value[i] <= value_cdb_slb;
            ready[i] <= 1'b1;
            j=i+1;
            while (j<rob_num && destination[j]!=destination[i]) j=j+1;
            if (j<rob_num) begin
                slb_new_entry <= entry[j];
            end
            else begin
                slb_new_entry <= 5'b0;
            end
        end

        //4.fetch commit
        //遍历state，找到最上层的2(可被commit的状态)，并通知相应部件进行执行，推出该指令, 并将整个rob向前移位
        j = 0;
        while (ready[j] != 1'b1 && j < rob_num) j=j+1;
        if (j>=rob_num) begin
            rob_have_commit <= 1'b0;
        end
        else begin
            rob_entry_commit <= entry[i];
            rob_destType_commit <= destType[i];
            rob_if_pc_c_commit <= pc_change[i];
            rob_new_pc_a_commit <= pc_value[i];
            rob_destination_commit <= destination[i];
            rob_value_commit <= value[i];
            for (i=j;i<rob_num;i=i+1) begin
                entry[i-1] <= entry[i];
                instr_origin[i-1] <= instr_origin[i];
                ready[i-1] <= ready[i];
                opcode[i-1] <= opcode[i];
                destType[i-1] <= destType[i];
                destination[i-1] <= destination[i];
                value[i-1] <= value[i];
                pc_value[i-1] <= pc_value[i];
                rd[i-1] <= rd[i];
                rs1[i-1] <= rs1[i];
                rs2[i-1] <= rs2[i];
                imm[i-1] <= imm[i];
            end
            rob_num <= rob_num-1;
        end


    end
end    
    
//将最后一个rob的信息输入regfile
regfile reg_qurey(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),

    .query          (1'b0),
    .reorder        (1'b1),
    .reorder_entry  (entry[rob_num]),
    .reorder_rd     (destination[rob_num]),
    
    .modify         (1'b0),
    .modify_entry   (5'b0),
    .modify_index   (5'b0),
    .modify_value   (32'b0),

    .query_entry    (),
    .query_value    ()
);


endmodule



/*ROB的工作
1.store the instruction from IF;
    case opcode and fetch the content in ROB(like destType, destination, value and so on)
2.if output_or_commit == output
    fetch the entry that can be output(the first one that not ready)
    need to know :
        1) arrive? rs/pc/slb
        2) the information of the instr
        3) about renaming : if one register is occupied, the entry of rs1 and rs2 that is occupied should be output 
3.recall the feedback from cdb
4.if output_or_commit == commit
    fetch the entry that can be committed (the first one that is ready)
    need to know :
        1)entry
        2)destType
        3)value
*/