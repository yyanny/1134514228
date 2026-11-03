module img_scale_nearest(
    input         clk,
    input         rst,

    // 源图像接口（对接BMP）
    input         src_req,
    output reg    src_ack,
    input         src_wr_en,
    input  [23:0] src_data,
    input  [15:0] src_w,
    input  [15:0] src_h,

    // 目标图像接口（对接帧缓存）
    output reg    dst_req,
    input         dst_ack,
    output reg    dst_wr_en,
    output reg [23:0] dst_data
);

localparam DST_W = 640;
localparam DST_H = 480;

// 状态机
localparam S_IDLE  = 2'd0;
localparam S_WAIT  = 2'd1;
localparam S_READ  = 2'd2;
localparam S_SEND  = 2'd3;

reg [1:0] state;

// 坐标与缩放系数（16位小数定点数）
reg [9:0]  dst_x;
reg [9:0]  dst_y;
reg [15:0] src_y_cnt;
reg [31:0] step_x;
reg [31:0] step_y;
reg [31:0] src_x_acc;

// 单行像素缓存，最大支持1024宽度
reg [23:0] line_buf [1023:0];
reg [9:0]  wr_ptr;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        state     <= S_IDLE;
        src_ack   <= 1'b0;
        dst_req   <= 1'b0;
        dst_wr_en <= 1'b0;
        dst_x     <= 10'd0;
        dst_y     <= 10'd0;
        src_y_cnt <= 16'd0;
        wr_ptr    <= 10'd0;
        src_x_acc <= 32'd0;
    end else begin
        case(state)
            S_IDLE: begin
                dst_wr_en <= 1'b0;
                if(src_req) begin
                    // 计算缩放步长
                    step_x    <= (src_w << 16) / DST_W;
                    step_y    <= (src_h << 16) / DST_H;
                    src_ack   <= 1'b1;
                    dst_req   <= 1'b1;
                    dst_x     <= 10'd0;
                    dst_y     <= 10'd0;
                    src_y_cnt <= 16'd0;
                    wr_ptr    <= 10'd0;
                    state     <= S_WAIT;
                end
            end

            S_WAIT: begin
                // 等待帧缓存应答写请求
                if(dst_ack) begin
                    state <= S_READ;
                end
            end

            S_READ: begin
                if(src_wr_en) begin
                    line_buf[wr_ptr] <= src_data;
                    wr_ptr <= wr_ptr + 1'b1;
                    // 单行读取完成
                    if(wr_ptr == src_w - 1'b1) begin
                        wr_ptr <= 10'd0;
                        src_y_cnt <= src_y_cnt + 1'b1;
                        // 命中目标行，开始发送
                        if(src_y_cnt == (dst_y * step_y) >> 16) begin
                            src_x_acc <= 32'd0;
                            state <= S_SEND;
                        end
                    end
                end
            end

            S_SEND: begin
                dst_wr_en <= 1'b1;
                // 最近邻取像素
                dst_data  <= line_buf[src_x_acc >> 16];
                src_x_acc <= src_x_acc + step_x;
                dst_x     <= dst_x + 1'b1;

                // 单行发送完成
                if(dst_x == DST_W - 1'b1) begin
                    dst_wr_en <= 1'b0;
                    dst_x     <= 10'd0;
                    dst_y     <= dst_y + 1'b1;
                    // 整帧完成
                    if(dst_y == DST_H - 1'b1) begin
                        state   <= S_IDLE;
                        src_ack <= 1'b0;
                        dst_req <= 1'b0;
                    end else begin
                        state <= S_READ;
                    end
                end
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
