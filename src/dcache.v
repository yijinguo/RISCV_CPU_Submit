module dcache #(
    parameter DCACHE_SIZE = 50
)(
    input   wire        clk_in,
    input   wire        rst_in,
    input   wire        rdy_in,
    input   wire        clear,
    //directly from memory
    input   wire        have_mem_in, 
    input   wire [ 7:0] mem_din,
    //from slb
    input   wire        have_slb_in,
    input   wire [ 4:0] slb_entry,
    input   wire        slb_wr, //1 for write
    input   wire [31:0] slb_mem_addr,
    input   wire [31:0] slb_mem_dout, //only when write

    //the data read from mem
    output  wire        have_mem_out,
    output  wire [ 4:0] mem_entry_out,
    output  wire [31:0] mem_din_out,
    //directly to memory
    output  wire        mem_signal, //0:do nothing
    output  wire [ 7:0] mem_dout,
    output  wire [31:0] mem_a,
    output  wire        mem_wr //1:write; 0:read
);

integer dcache_num;
reg [DCACHE_SIZE-1:0] wr_signal;
reg [ 4:0] entry[DCACHE_SIZE-1:0];
reg [31:0] mem_address[DCACHE_SIZE-1:0];
reg [31:0] mem_data[DCACHE_SIZE-1:0];

reg state = 1'b0;
reg current_wr = 1'b0;
integer current_loc;
reg [ 4:0] current_entry = 5'b0;
reg [31:0] current_mem_a = 32'b0;
reg [31:0] current_mem_data = 32'b0;

reg dcache_have_mem_out = 1'b0;
reg [ 4:0] dcache_mem_entry_out = 5'b0;
reg [31:0] dcache_mem_din_out = 32'b0;

reg dcache_mem_signal = 1'b0;
reg [ 7:0] dcache_mem_dout = 8'b0;
reg [31:0] dcache_mem_a = 32'b0;
reg dcache_mem_wr = 1'b0;

integer i;

assign have_mem_out = dcache_have_mem_out;
assign mem_entry_out = dcache_mem_entry_out;
assign mem_din_out = dcache_mem_din_out;

assign mem_signal = dcache_mem_signal;
assign mem_dout = dcache_mem_dout;
assign mem_a = dcache_mem_a;
assign mem_wr = dcache_mem_wr;


always @(posedge clk_in) begin
    if (rst_in || clear) begin
      current_entry <= 5'b0;
      dcache_num <= 0;
    end
    else if (!rdy_in) begin

    end
    else begin
        if (have_slb_in) begin
            entry[dcache_num] <= slb_entry;
            wr_signal[dcache_num] <= slb_wr;
            mem_address[dcache_num] <= slb_mem_addr;
            mem_data[dcache_num] <= slb_mem_dout; //todo : 转进制
            dcache_num <= dcache_num + 1;
        end

        if (state) begin //is executing
            if (current_wr) begin //write
                case (current_loc)
                    0: begin
                        dcache_mem_signal <= 1'b1;
                        dcache_mem_wr <= 1'b1;
                        current_loc <= 1;
                        dcache_mem_a <= current_mem_a;
                        dcache_mem_dout <= current_mem_data[7:0];
                    end
                    1: begin
                        dcache_mem_signal <= 1'b1;
                        dcache_mem_wr <= 1'b1;
                        current_loc <= 2;
                        dcache_mem_a <= current_mem_a + 8;
                        dcache_mem_dout <= current_mem_data[15:8];
                    end
                    2: begin
                        dcache_mem_signal <= 1'b1;
                        dcache_mem_wr <= 1'b1;
                        current_loc <= 3;
                        dcache_mem_a <= current_mem_a + 16;
                        dcache_mem_dout <= current_mem_data[23:16];
                    end
                    3: begin
                        dcache_mem_signal <= 1'b0;
                        current_loc <= 0;
                        dcache_mem_a <= current_mem_a + 24;
                        dcache_mem_dout <= current_mem_data[31:24];
                        state <= 1'b0;
                    end
                    default: ;
                endcase
            end
            else begin //read
                if (have_mem_in) begin
                    case (current_loc)
                        0: begin
                            dcache_mem_signal <= 1'b1;
                            dcache_mem_wr <= 1'b0;
                            current_loc <= 1;
                            current_mem_data[ 7:0] <= mem_din;
                            dcache_mem_a <= current_mem_a + 8;
                        end
                        1: begin
                            dcache_mem_signal <= 1'b1;
                            dcache_mem_wr <= 1'b0;
                            current_loc <= 2;
                            current_mem_data[15:8] <= mem_din;
                            dcache_mem_a <= current_mem_a + 16;
                        end
                        2: begin
                            dcache_mem_signal <= 1'b1;
                            dcache_mem_wr <= 1'b0;
                            current_loc <= 3;
                            current_mem_data[23:16] <= mem_din;
                            dcache_mem_a <= current_mem_a + 24;
                        end
                        3: begin
                            dcache_mem_signal <= 1'b0;
                            current_loc <= 0;
                            current_mem_data[31:24] <= mem_din;
                            state <= 1'b0;
                            dcache_have_mem_out <= 1'b1;
                            dcache_mem_entry_out <= current_entry;
                            dcache_mem_din_out <= current_mem_data;
                        end 
                    default: ;
                endcase
                end
            end
        end
        else begin //is not executing
            dcache_mem_signal <= 1'b0;
            if (dcache_num>0) begin
                state <= 1'b1;
                current_wr <= wr_signal[0];
                current_entry <= entry[0];
                current_mem_a <= mem_address[0];
                current_mem_data <= mem_data[0];
                dcache_num <= dcache_num - 1;
                for (i=0;i<dcache_num-1;i=i+1) begin
                    wr_signal[i] <= wr_signal[i+1];
                    entry[i] <= entry[i+1];
                    mem_address[i] <= mem_address[i+1];
                    mem_data[i] <= mem_data[i+1];
                end
            end
        end

    end
end

endmodule //dcache