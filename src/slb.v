module slb #(
    parameter SLB_SIZE = 10
)(
    input   wire            clk_in,
    input   wire            rst_in,
    input   wire            rdy_in,

    input   wire            from_rob,
    input   wire [ 4:0]     entry_in,
    input   wire [10:0]     opcode_in,
    input   wire [ 4:0]     rd_in, 
    input   wire [ 4:0]     rs1_in,
    input   wire [ 4:0]     rs2_in, 
    input   wire [31:0]     imm_in,

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

    input   wire            have_mem_in, //only for load
    input   wire [ 4:0]     mem_entry_in,
    input   wire [31:0]     mem_din,

    output  wire            slb_full,

    output  wire            have_cdb_out, //only for load
    output  wire [ 4:0]     entry_out,
    output  wire [31:0]     value_out,

    output  wire            slb_need,
    output  wire [ 4:0]     mem_entry_out,
    output  wire            mem_wr, //1 for write
    output  wire [31:0]     mem_addr,
    output  wire [31:0]     mem_dout //only when write
);


reg [ 4:0] slb_entry[SLB_SIZE-1:0];
reg [SLB_SIZE-1:0] ready; //0: not ready; 1:ready; 2:waiting(have been commited) 3:completed
reg [10:0] opcode[SLB_SIZE-1:0];
reg [ 4:0] rd[SLB_SIZE-1:0];
reg [31:0] vj[SLB_SIZE-1:0], vk[SLB_SIZE-1:0];
reg [ 4:0] qj[SLB_SIZE-1:0], qk[SLB_SIZE-1:0];
reg [31:0] imm[SLB_SIZE-1:0];
reg [63:0] value[SLB_SIZE-1:0];

integer slb_num = 0;
reg slb_full_signal = 1'b0;
reg slb_have_cdb_out;
reg [ 4:0] slb_entry_out;
reg [31:0] slb_value_out;
reg slb_need_signal = 1'b0;
reg [ 4:0] slb_mem_entry_out;
reg slb_mem_wr;
reg [31:0] slb_mem_addr;
reg [31:0] slb_mem_dout;

wire [ 4:0] qj0, qk0;
wire [31:0] vj0, vk0;

integer i, j;

assign slb_full = slb_full_signal;
assign have_cdb_out = slb_have_cdb_out;
assign entry_out = slb_entry_out;
assign value_out = slb_value_out;
assign slb_need = slb_need_signal;
assign mem_entry_out = slb_mem_entry_out;
assign mem_wr = slb_mem_wr;
assign mem_addr = slb_mem_addr;
assign mem_dout = slb_mem_dout;

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
    .modify_index   (rs1_in),
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
    .modify_index   (rs2_in),
    .modify_value   (32'b0),

    .query_entry    (qk0),
    .query_value    (vk0)
);

always @(posedge clk_in) begin
    if (rst_in) begin
        slb_num <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        slb_full_signal <= (slb_num == SLB_SIZE-2);

        //1.store the instruction from ROB;
        if (from_rob) begin
            slb_entry[slb_num] <= entry_in;
            opcode[slb_num] <= opcode_in;
            imm[slb_num] <= imm_in;
            qj[slb_num] <= qj0;
            case (opcode_in[6:0])
                7'b0000011: begin//load
                    qk[slb_num] <= 5'b0;
                    rd[slb_num] <= rd_in;
                    ready[slb_num] <= (qj0==5'b0);
                    vj[slb_num] <= vj0;                    
                    if (qj0==5'b0) value[slb_num][31:0] <= vj0 + imm_in;
                end
                7'b0100011: begin //store
                    qk[slb_num] <= qk0;
                    vj[slb_num] <= vj0;
                    vk[slb_num] <= vk0;
                    ready[slb_num] <= (qj0==5'b0 && qk0==5'b0);
                end
                default: ;
            endcase
            slb_num <= slb_num + 1;
        end

        //2.recall the feedback from cdb (commit);
         if (have_cdb_rs) begin
            for (i=0;i<slb_num;i=i+1) begin
                if (qj[i]==entry_cdb_rs) begin
                    qj[i] <= new_entry_cdb_rs;
                    vj[i] <= value_cdb_rs;
                end
                if (qk[i]==entry_cdb_rs) begin
                    qk[i] <= new_entry_cdb_rs;
                    vk[i] <= value_cdb_rs;
                end
                if ( (qj[i]==5'b0 || (qj[i]==entry_cdb_rs && new_entry_cdb_rs==5'b0)) 
                && ( qk[i]==5'b0 || (qk[i]==entry_cdb_rs && new_entry_cdb_rs==5'b0)) ) begin
                    ready[i] <= 1'b1;
                end
            end
        end
        if (have_cdb_branch) begin
            for (i=0;i<slb_num;i=i+1) begin
                if (qj[i]==entry_cdb_branch) begin
                    qj[i] <= new_entry_cdb_branch;
                    vj[i] <= value_cdb_branch;
                end
                if (qk[i]==entry_cdb_branch) begin
                    qk[i] <= new_entry_cdb_branch;
                    vk[i] <= value_cdb_branch;
                end
                if ( (qj[i]==5'b0 || (qj[i]==entry_cdb_branch && new_entry_cdb_branch==5'b0)) 
                && ( qk[i]==5'b0 || (qk[i]==entry_cdb_branch && new_entry_cdb_branch==5'b0)) ) begin
                    ready[i] <= 1'b1;
                end
            end
        end
        if (have_cdb_slb) begin
            for (i=0;i<slb_num;i=i+1) begin
                if (qj[i]==entry_cdb_slb) begin
                    qj[i] <= new_entry_cdb_slb;
                    vj[i] <= value_cdb_slb;
                end
                if (qk[i]==entry_cdb_slb) begin
                    qk[i] <= new_entry_cdb_slb;
                    vk[i] <= value_cdb_slb;
                end
                if ( (qj[i]==5'b0 || (qj[i]==entry_cdb_slb && new_entry_cdb_slb==5'b0)) 
                && ( qk[i]==5'b0 || (qk[i]==entry_cdb_slb && new_entry_cdb_slb==5'b0)) ) begin
                    ready[i] <= 1'b1;
                end
            end
        end

        //3.load: respond to the data from mem 
        if (have_mem_in) begin
            i = 0;
            while (i<slb_num && slb_entry[i] != mem_entry_in) i=i+1;  
            value[i] <= mem_din;       
            slb_have_cdb_out <= 1'b1;
            slb_entry_out <= slb_entry[i];
            slb_value_out <= value[i];
            for (j=i;i<slb_num;i=i+1) begin
                slb_entry[j] <= slb_entry[j+1];
                ready[j] <= ready[j+1];
                opcode[j] <= opcode[j+1];
                rd[j] <= rd[j+1];
                vj[j] <= vj[j+1];
                vk[j] <= vk[j+1];
                qj[j] <= qj[j+1];
                qk[j] <= qk[j+1];
                imm[j] <= imm[j+1];
                value[j] <= value[j+1];
            end
        end

        //4.select the ready one and throw out its entry to rob for commit;
        i = 0;
        while (i<slb_num && ready[i] != 1'b1) i=i+1;
        slb_need_signal <= (i<slb_num);
        if (i<slb_num) begin
            slb_mem_entry_out <= slb_entry[i];
            if (opcode[i][6:0]==7'b0000011) begin //load
                slb_mem_wr <= 1'b0;
                slb_mem_addr <= vj[i] + imm[i];
            end
            else begin
                slb_mem_wr <= 1'b1;
                slb_mem_addr <= vj[i] + imm[i];
                slb_mem_dout <= vk[i];
                for (j=i;i<slb_num;i=i+1) begin
                    slb_entry[j] <= slb_entry[j+1];
                    ready[j] <= ready[j+1];
                    opcode[j] <= opcode[j+1];
                    rd[j] <= rd[j+1];
                    vj[j] <= vj[j+1];
                    vk[j] <= vk[j+1];
                    qj[j] <= qj[j+1];
                    qk[j] <= qk[j+1];
                    imm[j] <= imm[j+1];
                    value[j] <= value[j+1];
                end
            end
        end

    end
end
    
endmodule


/*slb的动作
1.store the instruction from ROB;
2.recall the feedback from cdb (commit);
    1)op[2]=3/4  execute the content
    2)op[2]=0/1/5/6  modify the information
3.select the ready ones(state:1) and throw out its entry;
    1)load: load_reading has completed
    2)store: store waiting for commit to write
4.continue the execution of the instr load/store

*/