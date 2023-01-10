module IF #(
    parameter IF_SIZE = 20 //need to modify
)(
    input wire          clk_in,		
    input wire          rst_in,		
	input wire			rdy_in,	

    //from icache
    input  wire         icache_have_input,
    input  wire [31:0]  icache_instr_input,
    input  wire [31:0]  icache_instr_pc_input,
    //from rob
    input  wire         rob_full,    //1 if ROB is not full

    output wire         have_out,
    output wire [31:0]  instr_out,
    output wire [31:0]  instr_pc_out,
    output wire [16:0]  opcode_out,
    output wire [4:0]   rd_out,
    output wire [4:0]   rs1_out,
    output wire [4:0]   rs2_out,
    output wire [31:0]  imm_out,
    output wire         IF_not_full
);

reg [31:0] instr_queue[IF_SIZE-1:0]; //the size of instruction_queue can be modified
reg [31:0] instr_pc_queue[IF_SIZE-1:0];
reg[16:0] opcode[IF_SIZE-1:0];  //14:12+6:0
reg[4:0] rd[IF_SIZE-1:0];      //11:7
reg[4:0] rs1[IF_SIZE-1:0];     //19:15
reg[4:0] rs2[IF_SIZE-1:0];     //24:20
reg[31:0] imm[IF_SIZE-1:0];    
integer queue_num;

reg local_have_out;
reg [31:0] local_instr_out;
reg [31:0] local_instr_pc_out;
reg [16:0] local_opcode_out;
reg [4:0] local_rd_out;
reg [4:0] local_rs1_out;
reg [4:0] local_rs2_out;
reg [31:0] local_imm_out;

assign IF_not_full = (queue_num < IF_SIZE-2);
assign have_out = local_have_out;
assign instr_out = local_instr_out;
assign instr_pc_out = local_instr_pc_out;
assign opcode_out = local_opcode_out;
assign rd_out = local_rd_out;
assign rs1_out = local_rs1_out;
assign rs2_out = local_rs2_out;
assign imm_out = local_imm_out;

integer i;


always @(posedge clk_in) begin
    if (rst_in) begin
        queue_num <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        if (!rob_full && queue_num > 0) begin
            local_have_out <= 1'b1;
            local_instr_out <= instr_queue[0];
            local_instr_pc_out <= instr_pc_queue[0];
            local_opcode_out <= opcode[0];
            local_rd_out <= rd[0];
            local_rs1_out <= rs1[0];
            local_rs2_out <= rs2[0];
            local_imm_out = imm[0];
            for (i=0; i<queue_num-1; i=i+1) begin
                instr_queue[i] <= instr_queue[i+1];
                instr_pc_queue[i] <= instr_pc_queue[i+1];
                opcode[i] = opcode[i+1];
                rd[i] = rd[i+1];
                rs1[i] = rs1[i+1];
                rs2[i] = rs2[i+1];
                imm[i] = imm[i+1];
            end
            queue_num <= queue_num - 1;
        end
        else begin
            local_have_out <= 1'b0;
        end

        if (icache_have_input && queue_num < IF_SIZE-2) begin
            instr_queue[queue_num] <= icache_instr_input;
            instr_pc_queue[queue_num] <= icache_instr_pc_input;
            opcode[queue_num][6:0] <= icache_instr_input[6:0];
            opcode[queue_num][9:7] <= icache_instr_input[14:12];
            opcode[queue_num][16:10] <= icache_instr_input[31:25];
            rs1[queue_num] <= icache_instr_input[19:15];
            rs2[queue_num] <= icache_instr_input[24:20];
            rd[queue_num] <= icache_instr_input[11:7];
            queue_num <= queue_num + 1;
            case (opcode[queue_num][6:0])
                7'b0110111: imm[queue_num][31:12] <= icache_instr_input[31:12];
                7'b0010111: imm[queue_num][31:12] <= icache_instr_input[31:12];                    
                7'b1101111: begin
                    imm[queue_num][20] <= icache_instr_input[31];
                    imm[queue_num][10:1] <= icache_instr_input[30:21];
                    imm[queue_num][11] <= icache_instr_input[20];
                    imm[queue_num][19:12] <= icache_instr_input[19:12];
                end
                7'b1100111: imm[queue_num][11:0] <= icache_instr_input[31:20];
                7'b1100011: begin
                    imm[queue_num][12] <= icache_instr_input[31];
                    imm[queue_num][10:5] <= icache_instr_input[30:25];
                    imm[queue_num][4:1] <= icache_instr_input[11:8];
                    imm[queue_num][11] <=  icache_instr_input[7];
                end
                7'b0000011: imm[queue_num][11:0] <= icache_instr_input[31:20];
                7'b0100011: begin
                    imm[queue_num][11:5] <= icache_instr_input[31:25];
                    imm[queue_num][4:0] <= icache_instr_input[11:7];
                end
                7'b0010011: imm[queue_num][4:0] <= icache_instr_input[24:20];
            default: ;
          endcase
        end

       

      end
  end

endmodule //IF