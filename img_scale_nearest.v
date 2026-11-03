`timescale 1ns / 1ps

module img_scale_nearest(
    input               clk,
    input               rst,        // 高电平复位

    // 对接 bmp_read
    input               src_req,    // bmp写请求
    output reg          src_ack,    // 给bmp的请求应答
    input               src_wr_en,  // 源像素有效
    input       [23:0]  src_data,   // 源像素数据
    input       [15:0]  src_w,      // 源图像真实宽度
    input       [15:0]  src_h,      // 源图像真实高度

    // 对接 frame_read_write
    output reg          dst_req,    // 给frame的写请求
    input               dst_ack,    // frame回的应答
    output reg          dst_wr_en,  // 缩放后像素有效
    output reg  [23:0]  dst_data    // 缩放后像素数据
);

localparam DST_W = 16'd640;
localparam DST_H = 16'd480;

// 定点缩放步长，Q10格式
reg [25:0] x_step;
reg [25:0] y_step;

// 坐标计数器
reg [15:0] src_x;
reg [15:0] src_y;
reg [15:0] dst_x;
reg [15:0] dst_y;

localparam IDLE = 2'd0;
localparam WAIT_ACK = 2'd1;
localparam WORK = 2'd2;
reg [1:0] state;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        state <= IDLE;
        src_ack <= 1'b0;
        dst_req <= 1'b0;
        dst_wr_en <= 1'b0;
        dst_data <= 24'd0;
        src_x <= 16'd0;
        src_y <= 16'd0;
        dst_x <= 16'd0;
        dst_y <= 16'd0;
        x_step <= 26'd0;
        y_step <= 26'd0;
    end
    else begin
        src_ack <= 1'b0;
        dst_wr_en <= 1'b0;

        case(state)
            IDLE: begin
                dst_req <= 1'b0;
                if(src_req) begin
                    // 计算缩放步长：源尺寸/目标尺寸，定点Q10
                    x_step <= (src_w << 10) / DST_W;
                    y_step <= (src_h << 10) / DST_H;
                    src_x <= 16'd0;
                    src_y <= 16'd0;
                    dst_x <= 16'd0;
                    dst_y <= 16'd0;
                    // 先向frame发写请求
                    dst_req <= 1'b1;
                    state <= WAIT_ACK;
                end
            end

            WAIT_ACK: begin
                if(dst_ack) begin
                    dst_req <= 1'b0;
                    // frame应答后，再应答bmp，开始传输像素
                    src_ack <= 1'b1;
                    state <= WORK;
                end
            end

            WORK: begin
                if(src_wr_en) begin
                    // 源坐标步进
                    src_x <= src_x + 1'b1;
                    if(src_x == src_w - 1'b1) begin
                        src_x <= 16'd0;
                        src_y <= src_y + 1'b1;
                    end

                    // 最近邻采样判断
                    if( (dst_x * x_step) <= (src_x << 10)
                    &&  (dst_y * y_step) <= (src_y << 10) ) begin
                        dst_data <= src_data;
                        dst_wr_en <= 1'b1;
                        dst_x <= dst_x + 1'b1;

                        if(dst_x == DST_W - 1'b1) begin
                            dst_x <= 16'd0;
                            dst_y <= dst_y + 1'b1;
                        end
                    end

                    // 一帧缩放完成，回到空闲
                    if(dst_y == DST_H) begin
                        state <= IDLE;
                    end
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
