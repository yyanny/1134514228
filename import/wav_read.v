module wav_read(
    input clk,
    input rst,
    input load_start,
    input [31:0] load_sector,
    input sd_init_done,
    output reg sd_sec_read,
    output reg [31:0] sd_sec_read_addr,
    input [7:0] sd_sec_read_data,
    input sd_sec_read_data_valid,
    input sd_sec_read_end,
    output reg pcm_valid,
    output reg [15:0] pcm_left,
    output reg [15:0] pcm_right,
    output reg play_end
);

localparam ST_IDLE       = 4'd0;
localparam ST_READ_HEAD  = 4'd1;
localparam ST_PARSE_HEAD = 4'd2;
localparam ST_READ_DATA  = 4'd3;
localparam ST_DONE       = 4'd4;

reg [3:0] state;
reg [9:0] byte_cnt;
reg [1:0] sample_cnt;
reg [15:0] left_tmp;
reg head_valid;
reg [31:0] data_total_len;
reg [31:0] data_read_cnt;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        byte_cnt <= 10'd0;
    end else if(state == ST_READ_HEAD || state == ST_READ_DATA) begin
        if(sd_sec_read_data_valid)
            byte_cnt <= byte_cnt + 10'd1;
        else if(sd_sec_read_end)
            byte_cnt <= 10'd0;
    end else begin
        byte_cnt <= 10'd0;
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        head_valid <= 1'b0;
        data_total_len <= 32'd0;
    end else if(state == ST_READ_HEAD && sd_sec_read_data_valid) begin
        case(byte_cnt)
            10'd0: head_valid <= (sd_sec_read_data == 8'h52);
            10'd1: head_valid <= head_valid && (sd_sec_read_data == 8'h49);
            10'd2: head_valid <= head_valid && (sd_sec_read_data == 8'h46);
            10'd3: head_valid <= head_valid && (sd_sec_read_data == 8'h46);
            10'd22: head_valid <= head_valid && (sd_sec_read_data == 8'h02);
            10'd23: head_valid <= head_valid && (sd_sec_read_data == 8'h00);
            10'd24: head_valid <= head_valid && (sd_sec_read_data == 8'h80);
            10'd25: head_valid <= head_valid && (sd_sec_read_data == 8'hBB);
            10'd26: head_valid <= head_valid && (sd_sec_read_data == 8'h00);
            10'd27: head_valid <= head_valid && (sd_sec_read_data == 8'h00);
            10'd34: head_valid <= head_valid && (sd_sec_read_data == 8'h10);
            10'd35: head_valid <= head_valid && (sd_sec_read_data == 8'h00);
            10'd40: data_total_len[7:0]   <= sd_sec_read_data;
            10'd41: data_total_len[15:8]  <= sd_sec_read_data;
            10'd42: data_total_len[23:16] <= sd_sec_read_data;
            10'd43: data_total_len[31:24] <= sd_sec_read_data;
            default: ;
        endcase
    end
end

// 采样拼接：sample_cnt 仅在此块内驱动，消除多驱动
always @(posedge clk or posedge rst) begin
    if(rst) begin
        sample_cnt <= 2'd0;
        left_tmp <= 16'd0;
        pcm_valid <= 1'b0;
        pcm_left <= 16'd0;
        pcm_right <= 16'd0;
    end else begin
        pcm_valid <= 1'b0;
        if(state != ST_READ_DATA) begin
            sample_cnt <= 2'd0;
        end else if(sd_sec_read_data_valid) begin
            sample_cnt <= sample_cnt + 2'd1;
            case(sample_cnt)
                2'd0: left_tmp[7:0]   <= sd_sec_read_data;
                2'd1: left_tmp[15:8]  <= sd_sec_read_data;
                2'd2: pcm_right[7:0]  <= sd_sec_read_data;
                2'd3: begin
                    pcm_right[15:8] <= sd_sec_read_data;
                    pcm_left <= left_tmp;
                    pcm_valid <= 1'b1;
                end
            endcase
        end
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        state <= ST_IDLE;
        sd_sec_read <= 1'b0;
        sd_sec_read_addr <= 32'd0;
        play_end <= 1'b0;
        data_read_cnt <= 32'd0;
    end else if(!sd_init_done) begin
        state <= ST_IDLE;
        sd_sec_read <= 1'b0;
        play_end <= 1'b0;
    end else begin
        case(state)
            ST_IDLE: begin
                play_end <= 1'b0;
                sd_sec_read <= 1'b0;
                data_read_cnt <= 32'd0;
                if(load_start) begin
                    sd_sec_read_addr <= load_sector;
                    state <= ST_READ_HEAD;
                end
            end

            ST_READ_HEAD: begin
                sd_sec_read <= 1'b1;
                if(sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    state <= ST_PARSE_HEAD;
                end
            end

            ST_PARSE_HEAD: begin
                if(head_valid) begin
                    sd_sec_read_addr <= load_sector + 32'd1;
                    state <= ST_READ_DATA;
                end else begin
                    play_end <= 1'b1;
                    state <= ST_DONE;
                end
            end

            ST_READ_DATA: begin
                sd_sec_read <= 1'b1;
                if(sd_sec_read_data_valid) begin
                    data_read_cnt <= data_read_cnt + 32'd1;
                    if(data_read_cnt >= data_total_len - 32'd4) begin
                        sd_sec_read <= 1'b0;
                        play_end <= 1'b1;
                        state <= ST_DONE;
                    end
                end
                if(sd_sec_read_end) begin
                    sd_sec_read_addr <= sd_sec_read_addr + 32'd1;
                end
            end

            ST_DONE: begin
                sd_sec_read <= 1'b0;
                play_end <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
