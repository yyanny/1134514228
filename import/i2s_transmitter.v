module i2s_transmitter(
    input clk,          // 50MHz系统时钟
    input rst_n,
    input [15:0] audio_left,
    input [15:0] audio_right,
    output reg i2s_bck,
    output reg i2s_lck,
    output reg i2s_din
);

localparam BCK_DIV = 5'd15;

reg [4:0] bck_cnt;
reg [5:0] bit_cnt;
reg [63:0] left_shift;
reg [63:0] right_shift;
wire [23:0] left_24b;
wire [23:0] right_24b;

assign left_24b = {audio_left, 8'd0};
assign right_24b = {audio_right, 8'd0};

// BCK时钟生成
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        bck_cnt <= 5'd0;
        i2s_bck <= 1'b0;
    end else begin
        if(bck_cnt == BCK_DIV) begin
            bck_cnt <= 5'd0;
            i2s_bck <= ~i2s_bck;
        end else begin
            bck_cnt <= bck_cnt + 1'b1;
        end
    end
end

// 串行移位输出，标准I2S时序
always @(negedge i2s_bck or negedge rst_n) begin
    if(!rst_n) begin
        bit_cnt <= 6'd0;
        i2s_lck <= 1'b0;
        i2s_din <= 1'b0;
        left_shift <= 64'd0;
        right_shift <= 64'd0;
    end else begin
        if(bit_cnt == 6'd63) begin
            bit_cnt <= 6'd0;
            i2s_lck <= ~i2s_lck;
            if(i2s_lck) begin
                left_shift <= {left_24b, 40'd0};
            end else begin
                right_shift <= {right_24b, 40'd0};
            end
        end else begin
            bit_cnt <= bit_cnt + 6'd1;
        end

        if(i2s_lck) begin
            i2s_din <= right_shift[63];
            right_shift <= {right_shift[62:0], 1'b0};
        end else begin
            i2s_din <= left_shift[63];
            left_shift <= {left_shift[62:0], 1'b0};
        end
    end
end

endmodule
