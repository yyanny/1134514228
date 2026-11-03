`timescale 1ns / 1ps
`include "global_def.v"

module top(
input wire clk,
output wire sd_ncs,
output wire sd_dclk,
input wire sd_miso,
output wire sd_mosi,
input wire key_in,
//=====I2S音频输出端口（外接解码板）=====
output wire i2s_bck,
output wire i2s_lck,
output wire i2s_din,
//============================

output wire HDMI_CLK_P,
output wire HDMI_D0_P,
output wire HDMI_D1_P,
output wire HDMI_D2_P,
output wire HDMI_DDC_SCL,
inout wire HDMI_DDC_SDA,
output wire [5:0] seg_sel,
output wire [7:0] seg_data
);

// ====================== Clock & Reset ======================
wire video_clk;
wire hdmi_5x_clk;
wire hdmi_pll_lock;

PLL_0 u_hdmi_pll(
.refclk (clk),
.reset (1'b0),
.extlock (hdmi_pll_lock),
.clk0_out (video_clk),
.clk1_out (hdmi_5x_clk)
);

wire clk_125m;
wire clk_125m_sft;
wire sdram_pll_lock;

sys_pll u_sdram_pll(
.refclk (clk),
.reset (1'b0),
.extlock (sdram_pll_lock),
.clk0_out (),
.clk1_out (clk_125m),
.clk2_out (clk_125m_sft)
);

wire sys_rst_n = hdmi_pll_lock & sdram_pll_lock;

// ====================== SDRAM Controller ======================
wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;
wire App_wr_en;
wire [`ADDR_WIDTH-1:0] App_wr_addr;
wire [`DM_WIDTH-1:0] App_wr_dm;
wire [`DATA_WIDTH-1:0] App_wr_din;
wire App_rd_en;
wire [`ADDR_WIDTH-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [`DATA_WIDTH-1:0] Sdr_rd_dout;

sdram u_sdram(
.Clk (clk_125m),
.Clk_sft (clk_125m_sft),
.Rst (~sys_rst_n),
.Sdr_init_done (Sdr_init_done),
.Sdr_init_ref_vld (Sdr_init_ref_vld),
.Sdr_busy (Sdr_busy),
.App_wr_en (App_wr_en),
.App_wr_addr (App_wr_addr),
.App_wr_dm (App_wr_dm),
.App_wr_din (App_wr_din),
.App_rd_en (App_rd_en),
.App_rd_addr (App_rd_addr),
.Sdr_rd_en (Sdr_rd_en),
.Sdr_rd_dout (Sdr_rd_dout)
);

// ====================== 全局信号统一声明 ======================
// 帧缓存相关
wire write_finish;
wire read_req;
wire read_req_ack;
wire read_finish;
wire read_en;
wire [31:0] read_data;

// BMP原始信号
wire bmp_write_req;
wire bmp_write_req_ack;
wire bmp_data_wr_en;
wire [23:0] bmp_data;
wire [15:0] bmp_real_width;
wire [15:0] bmp_real_height;
wire bmp_sd_read_req;
wire [31:0] bmp_sd_read_addr;
wire [3:0] bmp_state_code;

// 缩放模块信号
wire scale_write_req;
wire scale_write_req_ack;
wire scale_wr_en;
wire [23:0] scale_data;

// SD卡全局总线
wire sd_init_done;
wire sd_sec_read;
wire [31:0] sd_sec_read_addr;
wire [7:0] sd_sec_read_data;
wire sd_sec_read_data_valid;
wire sd_sec_read_end;

// 音频相关
wire wav_sd_read;
wire [31:0] wav_sd_addr;
wire [15:0] wav_left;
wire [15:0] wav_right;
wire wav_pcm_valid;
wire wav_play_end;
wire audio_valid;
wire [23:0] audio_left;
wire [23:0] audio_right;
reg audio_valid_sync;
reg [23:0] audio_left_sync;
reg [23:0] audio_right_sync;
wire acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;

// 按键相关
wire key_trig;

// 图像水平偏移
localparam H_OFFSET = 6'd10;

// ====================== SD卡读仲裁（BMP优先级更高） ======================
assign sd_sec_read = bmp_sd_read_req ? bmp_sd_read_req : wav_sd_read;
assign sd_sec_read_addr = bmp_sd_read_req ? bmp_sd_read_addr : wav_sd_addr;

// 640x480分辨率直通，无需缩放
assign bmp_write_req_ack = scale_write_req_ack;
assign scale_write_req = bmp_write_req;
assign scale_wr_en = bmp_data_wr_en;

// 无颜色修正，BMP数据直通
assign scale_data = bmp_data;


// ====================== Frame Buffer ======================
frame_read_write #(
.MEM_DATA_BITS (32),
.READ_DATA_BITS (32),
.WRITE_DATA_BITS (32),
.ADDR_BITS (21),
.BURST_BITS (9),
.BURST_SIZE (256),
.WRITE_V_FLIP (1),
.FRAME_WIDTH (640),
.FRAME_HEIGHT (480)
) u_frame_rw(
.rst (~sys_rst_n),
.mem_clk (clk_125m),
.Sdr_init_done (Sdr_init_done),
.Sdr_init_ref_vld (Sdr_init_ref_vld),
.Sdr_busy (Sdr_busy),
.App_rd_en (App_rd_en),
.App_rd_addr (App_rd_addr),
.Sdr_rd_en (Sdr_rd_en),
.Sdr_rd_dout (Sdr_rd_dout),
.read_clk (video_clk),
.read_req (read_req),
.read_req_ack (read_req_ack),
.read_finish (read_finish),
.read_addr_0 (21'd18),
.read_addr_1 (21'd0),
.read_addr_2 (21'd0),
.read_addr_3 (21'd0),
.read_addr_index (2'd0),
.read_len (21'd307200),
.read_en (read_en),
.read_data (read_data),
.App_wr_en (App_wr_en),
.App_wr_addr (App_wr_addr),
.App_wr_din (App_wr_din),
.App_wr_dm (App_wr_dm),
.write_clk (clk),
.write_req (scale_write_req),
.write_req_ack (scale_write_req_ack),
.write_finish (write_finish),
.write_addr_0 (H_OFFSET),
.write_addr_1 (21'd0),
.write_addr_2 (21'd0),
.write_addr_3 (21'd0),
.write_addr_index (2'd0),
.write_len (21'd307200),
.write_en (scale_wr_en),
.write_data ({8'd0, scale_data})
);

// ====================== HDMI Timing ======================
reg [9:0] x_cnt;
reg [9:0] y_cnt;
wire hdmi_active;
wire axis_user;
wire axis_valid;
wire axis_last;
wire [23:0] axis_data;

always @(posedge video_clk or negedge sys_rst_n) begin
if(!sys_rst_n) begin
x_cnt <= 10'd0;
y_cnt <= 10'd0;
end else begin
if(x_cnt == 10'd799) begin
x_cnt <= 10'd0;
if(y_cnt == 10'd524)
y_cnt <= 10'd0;
else
y_cnt <= y_cnt + 1'b1;
end else begin
x_cnt <= x_cnt + 1'b1;
end
end
end

assign hdmi_active = (x_cnt < 10'd640) && (y_cnt < 10'd480);
assign axis_valid = hdmi_active;
assign axis_user = hdmi_active && (x_cnt == 10'd0) && (y_cnt == 10'd0);
assign axis_last = hdmi_active && (x_cnt == 10'd639);
assign axis_data = read_data[23:0];
assign read_en = hdmi_active;

// OSD 坐标与RGB对齐锁存
reg [9:0] pix_x;
reg [9:0] pix_y;
reg [23:0] rgb_raw;

always @(posedge video_clk or negedge sys_rst_n) begin
if(!sys_rst_n) begin
pix_x <= 10'd0;
pix_y <= 10'd0;
rgb_raw <= 24'd0;
end else begin
pix_x <= x_cnt;
pix_y <= y_cnt;
rgb_raw <= axis_data;
end
end

wire [23:0] rgb_after_osd;
osd_overlay u_osd_overlay (
.clk (video_clk),
.rst_n (sys_rst_n),
.pix_x (pix_x),
.pix_y (pix_y),
.rgb_in (rgb_raw),
.osd_en (1'b1),
.osd_data (8'd5),
.rgb_out (rgb_after_osd)
);

reg read_req_reg;
always @(posedge video_clk or negedge sys_rst_n) begin
if(!sys_rst_n) begin
read_req_reg <= 1'b0;
end else begin
if(axis_user) begin
read_req_reg <= 1'b1;
end else if(read_req_ack) begin
read_req_reg <= 1'b0;
end
end
end
assign read_req = read_req_reg;

// ====================== 内部音阶发生器（替代TF卡WAV） ======================
// 禁用SD卡音频读请求，不占用SD总线
assign wav_sd_read = 1'b0;
assign wav_sd_addr = 32'd0;
assign wav_play_end = 1'b0;

audio_tone_gen u_audio_tone(
    .clk (clk),
    .rst_n (sys_rst_n),
    .pcm_valid (wav_pcm_valid),
    .pcm_left (wav_left),
    .pcm_right (wav_right)
);

// 音频FIFO缓存
wire audio_fifo_wr_en;
wire [31:0] audio_fifo_wr_data;
wire audio_fifo_rd_en;
wire [31:0] audio_fifo_rd_data;
wire audio_fifo_empty;

assign audio_fifo_wr_en = wav_pcm_valid;
assign audio_fifo_wr_data = {wav_left, wav_right};

wfifo_32_32_512 u_audio_fifo(
.rst (~sys_rst_n),
.clkw (clk),
.clkr (clk),
.we (audio_fifo_wr_en),
.di (audio_fifo_wr_data),
.re (audio_fifo_rd_en),
.dout (audio_fifo_rd_data),
.valid (),
.full_flag (),
.empty_flag (audio_fifo_empty),
.afull (),
.aempty (),
.wrusedw (),
.rdusedw ()
);

// I2S LRCK沿触发读FIFO
reg i2s_lck_r;
always @(posedge clk or negedge sys_rst_n) begin
if(!sys_rst_n) begin
i2s_lck_r <= 1'b0;
end else begin
i2s_lck_r <= i2s_lck;
end
end
assign audio_fifo_rd_en = i2s_lck_r && !i2s_lck && !audio_fifo_empty;

// 静音兜底
wire [15:0] final_left;
wire [15:0] final_right;
assign final_left = audio_fifo_empty ? 16'd0 : audio_fifo_rd_data[31:16];
assign final_right = audio_fifo_empty ? 16'd0 : audio_fifo_rd_data[15:0];

// 扩展为24位兼容HDMI
assign audio_valid = !audio_fifo_empty;
assign audio_left = {final_left, 8'd0};
assign audio_right = {final_right, 8'd0};

// I2S发送模块
i2s_transmitter u_i2s_tx(
.clk (clk),
.rst_n (sys_rst_n),
.audio_left (final_left),
.audio_right(final_right),
.i2s_bck (i2s_bck),
.i2s_lck (i2s_lck),
.i2s_din (i2s_din)
);


// ACR计算模块
audio_arc_calculate u_acr(
.I_clk (video_clk),
.I_rst (~sys_rst_n),
.I_audio_valid (audio_valid_sync),
.O_acr_valid (acr_valid),
.O_acr_cts (acr_cts),
.O_acr_n (acr_n)
);

// 跨时钟域同步
reg audio_valid_r1;
reg [23:0] audio_left_r1, audio_left_sync;
reg [23:0] audio_right_r1, audio_right_sync;

always @(posedge video_clk or negedge sys_rst_n) begin
if(!sys_rst_n) begin
audio_valid_r1 <= 1'b0;
audio_valid_sync<= 1'b0;
audio_left_r1 <= 24'd0;
audio_left_sync <= 24'd0;
audio_right_r1 <= 24'd0;
audio_right_sync<= 24'd0;
end
else begin
audio_valid_r1 <= audio_valid;
audio_valid_sync<= audio_valid_r1;

audio_left_r1 <= audio_left;
audio_left_sync <= audio_left_r1;

audio_right_r1 <= audio_right;
audio_right_sync<= audio_right_r1;
end
end

// ====================== HDMI TX Core & PHY ======================
wire [9:0] ch0;
wire [9:0] ch1;
wire [9:0] ch2;
wire [9:0] clkch;

hdmi_1_4b_transmitter_core_wrapper #(
.DEVICE ("EG"),
.HTOTAL (800),
.HSA (96),
.HFP (16),
.HBP (48),
.HACTIVE (640),
.VTOTAL (525),
.VSA (2),
.VFP (10),
.VBP (33),
.VACTIVE (480),
.VIDEO_TPG ("Disable"),
.VIDEO_FORMAT ("RGB"),
.VIDEO_VIC (1),
.AUDIO_SAMPLE_RATE ("48K"),
.IIC_SCL_DIV (250)
) u_hdmi_core(
.I_pixel_clk (video_clk),
.I_rst (~sys_rst_n),
.I_edid_read_trig (1'b0),
.O_edid_read_valid (),
.O_edid_read_data (),
.I_axis_s_user (axis_user),
.I_axis_s_valid (axis_valid),
.I_axis_s_last (axis_last),
.I_axis_s_data(rgb_after_osd),
.O_axis_s_ready (),
.I_audio_valid (audio_valid_sync),
.I_audio_left_data (audio_left_sync),
.I_audio_right_data (audio_right_sync),
.I_acr_valid (acr_valid),
.I_acr_cts (acr_cts),
.I_acr_n (acr_n),
.O_video_locked (),
.O_ddc_scl (HDMI_DDC_SCL),
.IO_ddc_sda (HDMI_DDC_SDA),
.O_ch0_tmds_data (ch0),
.O_ch1_tmds_data (ch1),
.O_ch2_tmds_data (ch2),
.O_clk_tmds_data (clkch)
);

hdmi_phy_wrapper #(
.DEVICE ("EG")
) u_hdmi_phy(
.I_pixel_clk (video_clk),
.I_serial_clk (hdmi_5x_clk),
.I_rst (~sys_rst_n),
.I_tmds_channel_0 (ch0),
.I_tmds_channel_1 (ch1),
.I_tmds_channel_2 (ch2),
.I_tmds_channel_clk (clkch),
.O_tmds_ch0_p (HDMI_D0_P),
.O_tmds_ch1_p (HDMI_D1_P),
.O_tmds_ch2_p (HDMI_D2_P),
.O_tmds_clk_p (HDMI_CLK_P)
);

// ====================== 图片切换控制 ======================
localparam IMG_TOTAL = 2;
reg [9:0] y_cnt_r1, y_cnt_r2;
reg vsync_pulse;
reg pic_switch_req;

always @(posedge clk or negedge sys_rst_n) begin
if(!sys_rst_n) begin
y_cnt_r1 <= 10'd0;
y_cnt_r2 <= 10'd0;
vsync_pulse <= 1'b0;
end
else begin
y_cnt_r1 <= y_cnt;
y_cnt_r2 <= y_cnt_r1;
vsync_pulse <= (y_cnt_r2 == 10'd524);
end
end

reg [2:0] img_index;
reg [31:0] load_sector_sel;
reg load_start_reg;
reg init_load_done;
localparam CNT_MAX = 27'd100_000_000;
reg [26:0] cnt_auto;
reg auto_trig;

wire load_idle = (bmp_state_code == 4'd1);

always @(*) begin
case(img_index)
3'd0: load_sector_sel = 32'd32800;
3'd1: load_sector_sel = 32'd44712;
default: load_sector_sel = 32'd32800;
endcase
end

always @(posedge clk or negedge sys_rst_n) begin
if(!sys_rst_n) begin
img_index <= 3'd0;
load_start_reg <= 1'b0;
init_load_done <= 1'b0;
cnt_auto <= 27'd0;
auto_trig <= 1'b0;
pic_switch_req <= 1'b0;
end
else begin
load_start_reg <= 1'b0;
auto_trig <= 1'b0;

if(key_trig) begin
pic_switch_req <= 1'b1;
cnt_auto <= 27'd0;
end
else if(init_load_done && load_idle && !pic_switch_req) begin
if(cnt_auto == CNT_MAX - 1'd1) begin
cnt_auto <= 27'd0;
auto_trig <= 1'b1;
end
else begin
cnt_auto <= cnt_auto + 1'b1;
end
end

if(auto_trig) begin
pic_switch_req <= 1'b1;
end

if(!init_load_done && sd_init_done && load_idle) begin
init_load_done <= 1'b1;
load_start_reg <= 1'b1;
end
else if(pic_switch_req && load_idle && init_load_done && vsync_pulse) begin
pic_switch_req <= 1'b0;
if(img_index == IMG_TOTAL - 1'd1)
img_index <= 3'd0;
else
img_index <= img_index + 1'b1;
load_start_reg <= 1'b1;
end
end
end

// ====================== BMP Read Module ======================
bmp_read u_bmp(
.clk (clk),
.rst (~sys_rst_n),
.ready (),
.scan_start (1'b0),
.scan_start_sector (32'd0),
.scan_max_sector (32'd0),
.scan_target_count (3'd0),
.scan_done (),
.scan_found_valid (),
.scan_found_sector (),
.scan_found_total (),
.load_start (load_start_reg),
.load_abort (1'b0),
.load_sector (load_sector_sel),
.sd_init_done (sd_init_done),
.state_code (bmp_state_code),
.bmp_width (16'd1024),
.bmp_height (16'd768),
.write_req (bmp_write_req),
.write_req_ack (bmp_write_req_ack),
.sd_sec_read (bmp_sd_read_req),
.sd_sec_read_addr (bmp_sd_read_addr),
.sd_sec_read_data (sd_sec_read_data),
.sd_sec_read_data_valid (sd_sec_read_data_valid),
.sd_sec_read_end (sd_sec_read_end),
.bmp_data_wr_en (bmp_data_wr_en),
.bmp_data (bmp_data),
.bmp_real_width (bmp_real_width),
.bmp_real_height (bmp_real_height)
);

// ====================== SD Card Top ======================
sd_card_top #(
.SPI_LOW_SPEED_DIV (248),
.SPI_HIGH_SPEED_DIV (248)
) u_sd(
.clk (clk),
.rst (~sys_rst_n),
.SD_nCS (sd_ncs),
.SD_DCLK (sd_dclk),
.SD_MOSI (sd_mosi),
.SD_MISO (sd_miso),
.sd_init_done (sd_init_done),
.sd_sec_read (sd_sec_read),
.sd_sec_read_addr (sd_sec_read_addr),
.sd_sec_read_data (sd_sec_read_data),
.sd_sec_read_data_valid (sd_sec_read_data_valid),
.sd_sec_read_end (sd_sec_read_end),
.sd_sec_write (1'b0),
.sd_sec_write_addr (32'd0),
.sd_sec_write_data (8'd0),
.sd_sec_write_data_req (),
.sd_sec_write_end (),
.cmd_req_error (),
.cmd_last_r1 ()
);

// ====================== 按键消抖 ======================
key_remove_shakes u_key_debounce(
.I_clk (clk),
.I_rst_n (sys_rst_n),
.I_key_in (key_in),
.O_key_trig_out (key_trig)
);

// ====================== 7-Segment Display ======================
wire [3:0] show_state;
wire [6:0] seg_seg;

assign show_state = bmp_state_code;

seg_decoder u_seg_dec(
.bin_data (show_state),
.seg_data (seg_seg)
);

seg_scan u_seg_scan(
.clk (clk),
.rst_n (sys_rst_n),
.seg_sel (seg_sel),
.seg_data (seg_data),
.seg_data_0 ({1'b0, seg_seg}),
.seg_data_1 (8'hff),
.seg_data_2 (8'hff),
.seg_data_3 (8'hff),
.seg_data_4 (8'hff),
.seg_data_5 (8'hff)
);

endmodule
