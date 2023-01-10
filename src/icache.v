module icache #(
    parameter ICACHE_SIZE = 50
)(
    input wire            clk_in,		
    input wire            rst_in,		
	input wire			  rdy_in,

    input wire            have_mem_in,
    input wire [ 7:0]     mem_din,	

    input wire            pc_update,   //1 if pc is updated
    input wire [31:0]     pc_address,   //new pc address

    input wire            out_valid,    //1 if instruction can to be ouput

    output wire           have_out,     //1 if an instr is output
    output wire [31:0]    instr_out,    //new instruction output
    output wire [31:0]    instr_pc_out,

    output wire [31:0]    next_mem_addr
);

reg [31:0] current_addr;
reg [31:0] instr_cache[ICACHE_SIZE-1:0];  //icache content
reg [31:0] instr_pc[ICACHE_SIZE-1:0];

integer is_loading = 0; //0:0; 1:[7:0]; 2:[15:0]; 3:[23:0]; 4:[31:0]->0
reg [31:0] loaing_instr;
reg [31:0] loading_pc_address; //the beginning of the instr

reg index_head, index_tail;
integer not_full = 1;

reg local_have_out = 1'b0;
reg [31:0] local_instr_out;
reg [31:0] local_instr_pc_out;

integer i;

assign new_mem_addr = (pc_update) ? (pc_address) : (current_addr);
assign have_out = local_have_out;
assign instr_out = local_instr_out;
assign instr_pc_out = local_instr_pc_out;

initial begin
    //icache如果满了,删去已经输出的内容
    if (index_tail == ICACHE_SIZE - 2) begin
        for (i=index_head; i<index_tail; i=i+1) begin
            instr_cache[i-index_head] <= instr_cache[i];
            instr_pc[i-index_head] <= instr_pc[i];
        end
        index_head <= 0;
        index_tail <= index_tail - index_head;
    end
end

always @(posedge clk_in) begin
    if (rst_in) begin
        index_head <= 0;
        index_tail <= 0;
        not_full <= 1;
    end
    else if (!rdy_in) begin
        
    end
    else begin
        if (pc_update) begin
            current_addr <= pc_address;
            index_head <= 0;
            index_tail <= 0;
            not_full <= 1;
        end
        else begin
            if (index_head < index_tail) begin
                local_have_out <= (index_head < index_tail) ? 1'b1 : 1'b0;
                local_instr_out <= (index_head < index_tail) ? instr_cache[index_head] : 32'b0;
                local_instr_pc_out <= (index_head < index_tail) ? instr_pc[index_head] : 32'b0;
                index_head <= index_head + 1;
            end
            if (have_mem_in) begin
                current_addr <= current_addr + 8;
                case (is_loading)
                    0: begin
                        loaing_instr[ 7:0] <= mem_din;
                        is_loading <= 1;
                        loading_pc_address <= current_addr;
                    end
                    1: begin
                        loaing_instr[ 15:8] <= mem_din;
                        is_loading <= 2;
                    end
                    2: begin
                        loaing_instr[ 23:16] <= mem_din;
                        is_loading <= 3;
                    end
                    3: begin
                        loaing_instr[ 31:24] <= mem_din;
                        is_loading <= 4;
                    end
                    default: begin //4
                        instr_cache[index_tail] <= loaing_instr;
                        instr_pc[index_tail] <= loading_pc_address;
                        index_tail <= index_tail + 1;
                        loaing_instr[ 7:0] <= mem_din;
                        is_loading <= 1;
                        loading_pc_address <= current_addr;
                    end  
                endcase
            end
        end
        
    end
end

endmodule 