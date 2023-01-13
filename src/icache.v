module icache #(
    parameter ICACHE_SIZE = 50
)(
    input wire            clk_in,		
    input wire            rst_in,		
	input wire			  rdy_in,
    input wire            clear,

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

reg [31:0] current_addr = 32'b0;
reg [31:0] instr_cache[ICACHE_SIZE-1:0];  //icache content
reg [31:0] instr_pc[ICACHE_SIZE-1:0];

integer is_loading = 0; //0:0; 1:[7:0]; 2:[15:0]; 3:[23:0]; 4:[31:0]->0
reg [31:0] loading_instr = 32'b0;
reg [31:0] loading_pc_address = 32'b0; //the beginning of the instr

integer index_head = 0, index_tail = 0;
integer not_full = 1;

reg local_have_out = 1'b0;
reg [31:0] local_instr_out = 32'b0;
reg [31:0] local_instr_pc_out = 32'b0;

integer i;

assign next_mem_addr = (pc_update) ? (pc_address) : (current_addr);
assign have_out = local_have_out;
assign instr_out = local_instr_out;
assign instr_pc_out = local_instr_pc_out;


always @(posedge clk_in) begin
    if (rst_in || clear) begin
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
            if (out_valid && index_head < index_tail) begin
                local_have_out <= 1'b1;
                local_instr_out <= instr_cache[index_head];
                local_instr_pc_out <= instr_pc[index_head];
                index_head <= index_head + 1;
            end
            else begin
                local_have_out <= 1'b0;
                local_instr_out <= 32'b0;
                local_instr_pc_out <= 32'b0;
            end
            if (have_mem_in) begin
                current_addr <= current_addr + 1;
                case (is_loading)
                    0: begin
                        if (mem_din) begin
                            loading_instr[ 7:0] <= mem_din;
                            is_loading <= 1;
                            loading_pc_address <= current_addr;
                        end
                    end
                    1: begin
                        loading_instr[15:8] <= mem_din;
                        is_loading <= 2;
                    end
                    2: begin
                        loading_instr[23:16] <= mem_din;
                        is_loading <= 3;
                    end
                    3: begin
                        loading_instr[31:24] <= mem_din;
                        is_loading <= 4;
                    end
                    default: begin //4
                        instr_cache[index_tail] <= loading_instr;
                        instr_pc[index_tail] <= loading_pc_address;
                        index_tail <= index_tail + 1;
                        loading_instr[ 7:0] <= mem_din;
                        is_loading <= 1;
                        loading_pc_address <= current_addr-1;
                    end  
                endcase
            end
        end
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
end

endmodule 