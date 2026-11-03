module i2s_transmitter(
    input clk,
    input rst_n,
    input [15:0] audio_left,
    input [15:0] audio_right,
    output reg i2s_bck,
    output reg i2s_lck,
    output reg i2s_din
);

reg [4:0] cnt;
reg [3:0] bit_cnt;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt <= 5'd0;
        i2s_bck <= 1'b0;
    end
    else begin
        if(cnt == 5'd15) begin
            cnt <= 5'd0;
            i2s_bck <= ~i2s_bck;
        end
        else begin
            cnt <= cnt + 1'b1;
        end
    end
end

always @(negedge i2s_bck or negedge rst_n) begin
    if(!rst_n) begin
        bit_cnt <= 4'd0;
        i2s_lck <= 1'b0;
        i2s_din <= 1'b0;
    end
    else begin
        if(bit_cnt == 4'd15) begin
            bit_cnt <= 4'd0;
            i2s_lck <= ~i2s_lck;
        end
        else begin
            bit_cnt <= bit_cnt + 1'b1;
        end
        i2s_din <= i2s_lck ? audio_right[4'd15 - bit_cnt] : audio_left[4'd15 - bit_cnt];
    end
end

endmodule
