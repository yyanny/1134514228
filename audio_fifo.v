module audio_fifo(
    input clk,
    input rst_n,
    input wr_en,
    input [31:0] wr_data,
    output full,
    output almost_full,
    input rd_en,
    output [31:0] rd_data,
    output empty,
    output almost_empty
);

reg [31:0] mem [511:0];
reg [8:0] wr_ptr;
reg [8:0] rd_ptr;
reg [9:0] cnt;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wr_ptr <= 9'd0;
        rd_ptr <= 9'd0;
        cnt <= 10'd0;
    end else begin
        if(wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= wr_ptr + 9'd1;
        end
        if(rd_en && !empty) begin
            rd_ptr <= rd_ptr + 9'd1;
        end
        case({wr_en && !full, rd_en && !empty})
            2'b01: cnt <= cnt - 10'd1;
            2'b10: cnt <= cnt + 10'd1;
            default: cnt <= cnt;
        endcase
    end
end

assign rd_data = mem[rd_ptr];
assign full = (cnt == 10'd512);
assign almost_full = (cnt >= 10'd384);
assign empty = (cnt == 10'd0);
assign almost_empty = (cnt <= 10'd128);

endmodule
