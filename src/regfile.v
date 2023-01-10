module regfile #(
    parameter REG_SIZE = 32
)(
    input   wire        clk_in,
    input   wire        rst_in,
    input   wire        rdy_in,

    input   wire        query,

    input   wire        reorder,
    input   wire [ 4:0] reorder_entry,
    input   wire [ 4:0] reorder_rd,

    input   wire        modify, 
    input   wire [ 4:0] modify_entry,
    input   wire [ 4:0] modify_index,
    input   wire [31:0] modify_value, 
    
    output  wire [ 4:0] query_entry,
    output  wire [31:0] query_value   

);

reg [31:0] register[REG_SIZE-1:0];  //store the information of reg
reg [4:0] reg_entry[REG_SIZE-1:0];
reg busy[REG_SIZE-1:0];

assign query_entry = (query && busy[modify_index]) ? reg_entry[modify_index] : 0;
assign query_value = (query && !busy[modify_index]) ? register[modify_index] : 0;


integer i;
always @(posedge clk_in) begin
    if (rst_in) begin
        for (i=0;i<REG_SIZE;i=i+1) begin
            register[i]<=0;
            reg_entry[i]<=0;
            busy[i] <= 0;
        end
    end
    else if (!rdy_in) begin
        
    end
    else begin
        //query_entry <= (query && busy[modify_index]) ? reg_entry[modify_index] : 0;
        //query_value <= (query && !busy[modify_index]) ? register[modify_index] : 0;
        if (reorder) begin
            reg_entry[reorder_rd] <= reorder_entry;
            busy[reorder_rd] <= 1'b1;
        end
        if (modify) begin
            register[modify_index] <= modify_value;
            if (modify_entry == 1'b0) begin
                reg_entry[modify_index] <= 5'b0;
                busy[modify_index] <= 1'b0;
            end
            else if (reg_entry[modify_index] != modify_entry) begin
                reg_entry[modify_index] <= modify_entry;
                busy[modify_index] <= 1'b1;
            end
        end 
    end
end
    
endmodule