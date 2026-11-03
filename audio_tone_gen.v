module audio_tone_gen(
    input clk,
    input rst_n,
    output reg pcm_valid,
    output reg [15:0] pcm_left,
    output reg [15:0] pcm_right
);

localparam CNT_0_5S = 25'd12_500_000;
localparam DO = 16'd95420;
localparam RE = 16'd85034;
localparam MI = 16'd75758;
localparam FA = 16'd71633;
localparam SOL = 16'd63776;

reg [24:0] tone_cnt;
reg [2:0] tone_idx;
reg [16:0] freq_cnt;
reg [15:0] cur_freq;
reg wave;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        tone_cnt <= 25'd0;
        tone_idx <= 3'd0;
    end else begin
        if(tone_cnt == CNT_0_5S - 1'd1) begin
            tone_cnt <= 25'd0;
            if(tone_idx == 3'd4)
                tone_idx <= 3'd0;
            else
                tone_idx <= tone_idx + 1'd1;
        end else begin
            tone_cnt <= tone_cnt + 1'd1;
        end
    end
end

always @(*) begin
    case(tone_idx)
        3'd0: cur_freq = DO;
        3'd1: cur_freq = RE;
        3'd2: cur_freq = MI;
        3'd3: cur_freq = FA;
        3'd4: cur_freq = SOL;
        default: cur_freq = DO;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        freq_cnt <= 17'd0;
        wave <= 1'b0;
    end else begin
        if(freq_cnt == cur_freq - 1'd1) begin
            freq_cnt <= 17'd0;
            wave <= ~wave;
        end else begin
            freq_cnt <= freq_cnt + 1'd1;
        end
    end
end

always @(*) begin
    pcm_valid = 1'b1;
    pcm_left = wave ? 16'h7FFF : 16'h8000;
    pcm_right = wave ? 16'h7FFF : 16'h8000;
end

endmodule
