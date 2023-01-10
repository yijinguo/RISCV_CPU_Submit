// RISCV32I CPU top module
// port modification allowed for debugging purposes



module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire signal = 1'b1; //1:instruction; 0:data
wire pc_update = 1'b1;
wire [31:0] pc_address; //current_pc_address

wire icache_have_out = 1'b0;
wire [31:0] icache_instr_out;
wire [31:0] icache_instr_pc_out;
wire [31:0] icache_expect_mem_a; 

wire IF_not_full = 1'b1;
wire rob_full = 1'b0;

wire IF_have_output = 1'b0;
wire [31:0] IF_instr;
wire [31:0] IF_instr_pc;
wire [16:0] IF_opcode;
wire [4:0] IF_rd;
wire [4:0] IF_rs1;
wire [4:0] IF_rs2;
wire [31:0] IF_imm;


wire slb_need;
wire [ 4:0] slb_entry_out;
wire slb_wr_out;
wire [31:0] slb_mem_addr_out;
wire [31:0] slb_mem_dout_out;

wire dcache_have_mem_in;
wire [ 4:0] dcache_entry_in;
wire [31:0] dcache_data_in;
wire [31:0] dcache_mem_a;
wire dcache_signal = 1'b0; //0:do nothing ; 1:have something
wire dcache_wr = 1'b0;

//data bus
wire cdb_rs_modify;
wire [ 4:0] cdb_rs_entry;
wire [31:0] cdb_rs_value;
wire cdb_branch_modify;
wire [ 4:0] cdb_branch_entry;
wire [31:0] cdb_branch_value;
wire cdb_branch_if_pc_change;
wire [31:0] cdb_branch_new_pc_addr;
wire cdb_slb_modify;
wire [4:0] cdb_slb_entry;
wire [31:0] cdb_slb_value;

wire rob_cdb_rs_m;
wire [ 4:0] rob_cdb_rs_entry; 
wire [ 4:0] rob_cdb_rs_new_entry;
wire [ 4:0] rob_cdb_rs_rd;
wire [31:0] rob_cdb_rs_value;
wire rob_cdb_br_m;
wire [ 4:0] rob_cdb_br_entry; 
wire [ 4:0] rob_cdb_br_new_entry;
wire [ 4:0] rob_cdb_br_rd;
wire [31:0] rob_cdb_br_value;
wire rob_cdb_br_if_pc_c;
wire [31:0] rob_cdb_br_new_pc_a;
wire rob_cdb_slb_m;
wire [ 4:0] rob_cdb_slb_entry; 
wire [ 4:0] rob_cdb_slb_new_entry;
wire [ 4:0] rob_cdb_slb_rd;
wire [31:0] rob_cdb_slb_value;

//rob
wire rob_have_out = 1'b0;
wire [1:0] rob_slb_or_rs_or_pc; //0 arrive slb, 1 arrive rs, 2 arrive pc(branch)
wire rob_is_jump_out;
wire [ 4:0] rob_entry_out;
wire [10:0] rob_opcode_out;
wire [ 4:0] rob_rd_out;
wire [31:0] rob_pc_address_out;
wire [ 4:0] rob_rs1_out, rob_rs2_out;
wire [31:0] rob_imm_out;

//commit info
wire have_commit = 1'b0;
wire [ 4:0] commit_entry;
wire [ 1:0] commit_destType; //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
wire commit_if_pc_change = 1'b0;
wire [31:0] commit_new_pc_address;
wire [ 4:0] commit_destination;
wire [31:0] commit_value;

wire rs_full = 1'b0;
wire slb_full = 1'b0;

assign signal = (!dcache_signal);
assign mem_wr = (dcache_signal && dcache_wr);
assign mem_a = (dcache_signal && !dcache_wr) ? dcache_mem_a : pc_address;
assign pc_update = ((commit_destType==2'b10|commit_destType==2'b11) && commit_if_pc_change);
assign pc_address = commit_new_pc_address;

icache icache_running(
  .clk_in       (clk_in),
  .rst_in       (rst_in),
  .rdy_in       (rdy_in),
  .have_mem_in  (signal),
  .mem_din      (mem_din),
  .pc_update    (pc_update),
  .pc_address   (pc_address),
  .out_valid    (IF_not_full),

  .have_out     (icache_have_out),
  .instr_out    (icache_instr_out),
  .instr_pc_out (icache_instr_pc_out),

  .next_mem_addr (icache_expect_mem_a)
);

IF IF_running(
  .clk_in               (clk_in),
  .rst_in               (rst_in),
  .rdy_in               (rdy_in),
  .icache_have_input    (icache_have_out),
  .icache_instr_input   (icache_instr_out),
  .icache_instr_pc_input(icache_instr_pc_out),
  .rob_full             (rob_full),

  .have_out             (IF_have_output),
  .instr_out            (IF_instr),
  .instr_pc_out         (IF_instr_pc),
  .opcode_out           (IF_opcode),
  .rd_out               (IF_rd),
  .rs1_out              (IF_rs1),
  .rs2_out              (IF_rs2),
  .imm_out              (IF_imm),
  .IF_not_full          (IF_not_full) 
);

rob rob_running(
  .clk_in         (clk_in),
  .rst_in         (rst_in),
  .rdy_in         (rdy_in),
  .have_input     (IF_have_output),
  .instr_input    (IF_instr),
  .instr_input_pc (IF_instr_pc),
  .opcode_if      (IF_opcode),
  .rd_if          (IF_rd),
  .rs1_if         (IF_rs1),
  .rs2_if         (IF_rs2),
  .imm_if         (IF_imm),

  .have_cdb_rs        (cdb_rs_modify),
  .entry_cdb_rs       (cdb_rs_entry),
  .value_cdb_rs       (cdb_rs_value),
  .have_cdb_branch    (cdb_branch_modify),
  .entry_cdb_branch   (cdb_branch_entry),
  .value_cdb_branch   (cdb_branch_value),
  .branch_if_pc_c     (cdb_branch_if_pc_change),
  .branch_new_pc_a    (cdb_branch_new_pc_addr),
  .have_cdb_slb       (cdb_slb_modify),
  .entry_cdb_slb      (cdb_slb_entry),
  .value_cdb_slb      (cdb_slb_value),

  .have_rs_out            (rob_cdb_rs_m),
  .rd_cdb_rs              (rob_cdb_rs_rd),
  .new_entry_cdb_rs       (rob_cdb_rs_new_entry),
  .entry_rs               (rob_cdb_rs_entry),
  .value_rs               (rob_cdb_rs_value),
  .have_branch_out        (rob_cdb_br_m),
  .rd_cdb_branch          (rob_cdb_br_rd),
  .new_entry_cdb_branch   (rob_cdb_br_new_entry),
  .entry_branch           (rob_cdb_br_entry),
  .value_branch           (rob_cdb_br_value),
  .if_pc_c_branch         (rob_cdb_br_if_pc_c),
  .new_pc_a_branch        (rob_cdb_br_new_pc_a),
  .have_slb_out           (rob_cdb_slb_m),
  .rd_cdb_slb             (rob_cdb_slb_rd),
  .new_entry_cdb_slb      (rob_cdb_slb_new_entry),
  .entry_slb              (rob_cdb_slb_entry),
  .value_slb              (rob_cdb_slb_value),

  .have_out               (rob_have_out),
  .is_jump                (rob_is_jump_out),
  .slb_or_rs_or_pc        (rob_slb_or_rs_or_pc),
  .entry_out              (rob_entry_out),
  .opcode_out             (rob_opcode_out),
  .pc_address_out         (rob_pc_address_out),
  .rd_out                 (rob_rd_out),
  .rs1_out                (rob_rs1_out),
  .rs2_out                (rob_rs2_out),
  .imm_out                (rob_imm_out),

  .have_commit            (have_commit),
  .entry_commit           (commit_entry),
  .destType_commit        (commit_destType),
  .if_pc_change_commit    (commit_if_pc_change),
  .new_pc_address_commit  (commit_new_pc_address),
  .destination_commit     (commit_destination),
  .value_commit           (commit_value),

  .rob_full               (rob_full)
);

rs rs_running(
  .clk_in                 (clk_in),
  .rst_in                 (rst_in),
  .rdy_in                 (rdy_in),
  .from_rob               (rob_have_out && rob_slb_or_rs_or_pc==2'b01),
  .entry_in               (rob_entry_out),
  .opcode_in              (rob_opcode_out),
  .pc_address_in          (rob_pc_address_out),
  .rs1_in                 (rob_rs1_out),
  .rs2_in                 (rob_rs2_out),
  .imm_in                 (rob_imm_out),

  .have_cdb_rs            (rob_cdb_rs_m),
  .entry_cdb_rs           (rob_cdb_rs_entry),
  .new_entry_cdb_rs       (rob_cdb_rs_new_entry),
  .value_cdb_rs           (rob_cdb_rs_value),
  .have_cdb_branch        (rob_cdb_br_m),
  .entry_cdb_branch       (rob_cdb_br_entry),
  .new_entry_cdb_branch   (rob_cdb_br_new_entry),
  .value_cdb_branch       (rob_cdb_br_value),
  .have_cdb_slb           (rob_cdb_slb_m),
  .entry_cdb_slb          (rob_cdb_slb_entry),
  .new_entry_cdb_slb      (rob_cdb_slb_new_entry),
  .value_cdb_slb          (rob_cdb_slb_value),

  .rs_full                (rs_full),
  .have_execute           (cdb_rs_modify),
  .entry_execute          (cdb_rs_entry),
  .result                 (cdb_rs_value)
);

branch branch_running(
  .clk_in       (clk_in),
  .rst_in       (rst_in),
  .rdy_in       (rdy_in),
  .have_input       (rob_have_out && rob_slb_or_rs_or_pc == 2'b10),
  .entry_input      (rob_entry_out),
  .opcode_input     (rob_opcode_out),
  .pc_address_input (rob_pc_address_out),
  .rs1_input        (rob_rs1_out),
  .rs2_input        (rob_rs2_out),
  .imm_input        (rob_imm_out),

  .have_cdb_rs            (rob_cdb_rs_m),
  .entry_cdb_rs           (rob_cdb_rs_entry),
  .new_entry_cdb_rs       (rob_cdb_rs_new_entry),
  .value_cdb_rs           (rob_cdb_rs_value),
  .have_cdb_branch        (rob_cdb_br_m),
  .entry_cdb_branch       (rob_cdb_br_entry),
  .new_entry_cdb_branch   (rob_cdb_br_new_entry),
  .value_cdb_branch       (rob_cdb_br_value),
  .have_cdb_slb           (rob_cdb_slb_m),
  .entry_cdb_slb          (rob_cdb_slb_entry),
  .new_entry_cdb_slb      (rob_cdb_slb_new_entry),
  .value_cdb_slb          (rob_cdb_slb_value),

  .have_out             (cdb_branch_modify),
  .entry_out            (cdb_branch_entry),
  .if_pc_change_out     (cdb_branch_if_pc_change),
  .new_pc_address_out   (cdb_branch_new_pc_addr),
  .value_out            (cdb_branch_value)
);


dcache dcache_running(
  .clk_in         (clk_in),
  .rst_in         (rst_in),
  .rdy_in         (rdy_in),

  .have_mem_in    (!signal),
  .mem_din        (mem_din),

  .have_slb_in    (slb_need),
  .slb_entry      (slb_entry_out),
  .slb_wr         (slb_wr_out),
  .slb_mem_addr   (slb_mem_addr_out),
  .slb_mem_dout   (slb_mem_dout_out),

  .have_mem_out   (dcache_have_mem_in),
  .mem_entry_out  (dcache_entry_in),
  .mem_din_out    (dcache_data_in),

  .mem_signal     (dcache_signal),
  .mem_dout       (mem_dout),
  .mem_a          (dcache_mem_a),
  .mem_wr         (dcache_wr)
);

slb slb_running(
  .clk_in                 (clk_in),
  .rst_in                 (rst_in),
  .rdy_in                 (rdy_in),
  .from_rob               (rob_have_out && rob_slb_or_rs_or_pc == 2'b00),
  .entry_in               (rob_entry_out),
  .opcode_in              (rob_opcode_out),
  .rd_in                  (rob_rd_out),
  .rs1_in                 (rob_rs1_out),
  .rs2_in                 (rob_rs2_out),
  .imm_in                 (rob_imm_out),   

  .have_cdb_rs            (rob_cdb_rs_m),
  .entry_cdb_rs           (rob_cdb_rs_entry),
  .new_entry_cdb_rs       (rob_cdb_rs_new_entry),
  .value_cdb_rs           (rob_cdb_rs_value),
  .have_cdb_branch        (rob_cdb_br_m),
  .entry_cdb_branch       (rob_cdb_br_entry),
  .new_entry_cdb_branch   (rob_cdb_br_new_entry),
  .value_cdb_branch       (rob_cdb_br_value),
  .have_cdb_slb           (rob_cdb_slb_m),
  .entry_cdb_slb          (rob_cdb_slb_entry),
  .new_entry_cdb_slb      (rob_cdb_slb_new_entry),
  .value_cdb_slb          (rob_cdb_slb_value),

  .have_mem_in            (dcache_have_mem_in),
  .mem_entry_in           (dcache_entry_in),
  .mem_din                (dcache_data_in),

  .slb_full               (slb_full),
  .have_cdb_out           (cdb_slb_modify),
  .entry_out              (cdb_slb_entry),
  .value_out              (cdb_slb_value),

  .slb_need               (slb_need),
  .mem_entry_out          (slb_entry_out),
  .mem_wr                 (slb_wr_out),
  .mem_addr               (slb_mem_addr_out),
  .mem_dout               (slb_mem_dout_out)

);

regfile reg_rs(
    .clk_in         (clk_in),
    .rst_in         (rst_in),
    .rdy_in         (rdy_in),

    .query          (1'b0),
    .reorder        (1'b0),
    .reorder_entry  (5'b0),
    .reorder_rd     (5'b0),
    
    .modify         (rob_cdb_rs_m),
    .modify_entry   (rob_cdb_rs_entry),
    .modify_index   (rob_cdb_rs_rd),
    .modify_value   (rob_cdb_rs_value),

    .query_entry    (),
    .query_value    ()
);

regfile reg_branch(
    .clk_in         (clk_in),
    .rst_in         (rst_in),
    .rdy_in         (rdy_in),

    .query          (1'b0),
    .reorder        (1'b0),
    .reorder_entry  (5'b0),
    .reorder_rd     (5'b0),
    
    .modify         (rob_cdb_br_m),
    .modify_entry   (rob_cdb_br_entry),
    .modify_index   (rob_cdb_br_rd),
    .modify_value   (rob_cdb_br_value),

    .query_entry    (),
    .query_value    ()
);

regfile reg_slb(
    .clk_in         (clk_in),
    .rst_in         (rst_in),
    .rdy_in         (rdy_in),

    .query          (1'b0),
    .reorder        (1'b0),
    .reorder_entry  (5'b0),
    .reorder_rd     (5'b0),
    
    .modify         (rob_cdb_slb_m),
    .modify_entry   (rob_cdb_slb_entry),
    .modify_index   (rob_cdb_slb_rd),
    .modify_value   (rob_cdb_slb_value),

    .query_entry    (),
    .query_value    ()
);


endmodule