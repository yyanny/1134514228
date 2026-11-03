module fat32_root_scan(
input clk,
input rst,
input sd_init_done,
input scan_start,
input [87:0] target_filename,
output reg scan_done,
output reg scan_found,
output reg [31:0] file_start_sector,
output reg [31:0] file_size,
output reg sd_sec_read,
output reg [31:0] sd_sec_read_addr,
input [7:0] sd_sec_read_data,
input sd_sec_read_data_valid,
input sd_sec_read_end,
output reg [3:0] state_code
);

localparam ST_IDLE = 4'd0;
localparam ST_READ_MBR = 4'd1;
localparam ST_PARSE_MBR = 4'd2;
localparam ST_READ_DBR = 4'd3;
localparam ST_PARSE_DBR = 4'd4;
localparam ST_READ_DIR = 4'd5;
localparam ST_PARSE_DIR = 4'd6;
localparam ST_NEXT_SEC = 4'd7;
localparam ST_FOUND = 4'd8;
localparam ST_NOT_FOUND = 4'd9;

reg [3:0] state;
reg [9:0] rd_cnt;
reg [31:0] partition_start_sec;
reg [7:0] sec_per_clus;
reg [15:0] rsvd_sec_cnt;
reg [7:0] num_fats;
reg [31:0] fat_size;
reg [31:0] root_clus;
reg [31:0] data_area_start_sec;
reg [31:0] current_dir_sec;
reg [5:0] dir_entry_idx;
reg [87:0] cur_dir_name;
reg [31:0] cur_dir_clus;
reg [31:0] cur_dir_size;
reg name_match;
reg mbr_valid;

always @(posedge clk or posedge rst) begin
if(rst) begin
rd_cnt <= 10'd0;
end else if(state == ST_READ_MBR || state == ST_READ_DBR || state == ST_READ_DIR) begin
if(sd_sec_read_data_valid)
rd_cnt <= rd_cnt + 10'd1;
else if(sd_sec_read_end)
rd_cnt <= 10'd0;
end else begin
rd_cnt <= 10'd0;
end
end

always @(posedge clk or posedge rst) begin
if(rst) begin
partition_start_sec <= 32'd0;
mbr_valid <= 1'b0;
end else if(state == ST_READ_MBR && sd_sec_read_data_valid) begin
case(rd_cnt)
10'h1C6: partition_start_sec[7:0] <= sd_sec_read_data;
10'h1C7: partition_start_sec[15:8] <= sd_sec_read_data;
10'h1C8: partition_start_sec[23:16] <= sd_sec_read_data;
10'h1C9: partition_start_sec[31:24] <= sd_sec_read_data;
10'h1FE: mbr_valid <= (sd_sec_read_data == 8'h55);
10'h1FF: mbr_valid <= mbr_valid && (sd_sec_read_data == 8'hAA);
default: ;
endcase
end
end

always @(posedge clk or posedge rst) begin
if(rst) begin
sec_per_clus <= 8'd0;
rsvd_sec_cnt <= 16'd0;
num_fats <= 8'd0;
fat_size <= 32'd0;
root_clus <= 32'd0;
end else if(state == ST_READ_DBR && sd_sec_read_data_valid) begin
case(rd_cnt)
10'd13: sec_per_clus <= sd_sec_read_data;
10'd14: rsvd_sec_cnt[7:0] <= sd_sec_read_data;
10'd15: rsvd_sec_cnt[15:8] <= sd_sec_read_data;
10'd16: num_fats <= sd_sec_read_data;
10'd36: fat_size[7:0] <= sd_sec_read_data;
10'd37: fat_size[15:8] <= sd_sec_read_data;
10'd38: fat_size[23:16] <= sd_sec_read_data;
10'd39: fat_size[31:24] <= sd_sec_read_data;
10'd44: root_clus[7:0] <= sd_sec_read_data;
10'd45: root_clus[15:8] <= sd_sec_read_data;
10'd46: root_clus[23:16]<= sd_sec_read_data;
10'd47: root_clus[31:24]<= sd_sec_read_data;
default: ;
endcase
end
end

always @(posedge clk or posedge rst) begin
if(rst) begin
cur_dir_name <= 88'd0;
cur_dir_clus <= 32'd0;
cur_dir_size <= 32'd0;
dir_entry_idx <= 6'd0;
end else if(state == ST_READ_DIR && sd_sec_read_data_valid) begin
case(rd_cnt[4:0])
5'd0: cur_dir_name[87:80] <= sd_sec_read_data;
5'd1: cur_dir_name[79:72] <= sd_sec_read_data;
5'd2: cur_dir_name[71:64] <= sd_sec_read_data;
5'd3: cur_dir_name[63:56] <= sd_sec_read_data;
5'd4: cur_dir_name[55:48] <= sd_sec_read_data;
5'd5: cur_dir_name[47:40] <= sd_sec_read_data;
5'd6: cur_dir_name[39:32] <= sd_sec_read_data;
5'd7: cur_dir_name[31:24] <= sd_sec_read_data;
5'd8: cur_dir_name[23:16] <= sd_sec_read_data;
5'd9: cur_dir_name[15:8] <= sd_sec_read_data;
5'd10: cur_dir_name[7:0] <= sd_sec_read_data;
5'd20: cur_dir_clus[23:16] <= sd_sec_read_data;
5'd21: cur_dir_clus[31:24] <= sd_sec_read_data;
5'd26: cur_dir_clus[7:0] <= sd_sec_read_data;
5'd27: cur_dir_clus[15:8] <= sd_sec_read_data;
5'd28: cur_dir_size[7:0] <= sd_sec_read_data;
5'd29: cur_dir_size[15:8] <= sd_sec_read_data;
5'd30: cur_dir_size[23:16] <= sd_sec_read_data;
5'd31: cur_dir_size[31:24] <= sd_sec_read_data;
default: ;
endcase
if(rd_cnt[4:0] == 5'd31)
dir_entry_idx <= dir_entry_idx + 6'd1;
end else if(state == ST_NEXT_SEC) begin
dir_entry_idx <= 6'd0;
end
end

always @(*) begin
name_match = (cur_dir_name == target_filename) && (cur_dir_name[87:80] != 8'hE5) && (cur_dir_name[87:80] != 8'h00);
end

always @(posedge clk or posedge rst) begin
if(rst) begin
state <= ST_IDLE;
state_code <= 4'd0;
sd_sec_read <= 1'b0;
sd_sec_read_addr <= 32'd0;
scan_done <= 1'b0;
scan_found <= 1'b0;
file_start_sector <= 32'd0;
file_size <= 32'd0;
data_area_start_sec <= 32'd0;
current_dir_sec <= 32'd0;
end else if(!sd_init_done) begin
state <= ST_IDLE;
state_code <= 4'd0;
sd_sec_read <= 1'b0;
scan_done <= 1'b0;
scan_found <= 1'b0;
end else begin
case(state)
ST_IDLE: begin
state_code <= 4'd1;
sd_sec_read <= 1'b0;
scan_done <= 1'b0;
scan_found <= 1'b0;
if(scan_start) begin
sd_sec_read_addr <= 32'd0;
state <= ST_READ_MBR;
end
end

ST_READ_MBR: begin
state_code <= 4'd2;
sd_sec_read <= 1'b1;
if(sd_sec_read_end) begin
sd_sec_read <= 1'b0;
state <= ST_PARSE_MBR;
end
end

ST_PARSE_MBR: begin
state_code <= 4'd3;
if(!mbr_valid) begin
    sd_sec_read_addr <= 32'd0;
end else begin
    sd_sec_read_addr <= partition_start_sec;
end
state <= ST_READ_DBR;
end

ST_READ_DBR: begin
state_code <= 4'd4;
sd_sec_read <= 1'b1;
if(sd_sec_read_end) begin
sd_sec_read <= 1'b0;
state <= ST_PARSE_DBR;
end
end

ST_PARSE_DBR: begin
state_code <= 4'd5;
data_area_start_sec <= partition_start_sec + rsvd_sec_cnt + num_fats * fat_size;
current_dir_sec <= partition_start_sec + rsvd_sec_cnt + num_fats * fat_size + (root_clus - 32'd2) * sec_per_clus;
sd_sec_read_addr <= partition_start_sec + rsvd_sec_cnt + num_fats * fat_size + (root_clus - 32'd2) * sec_per_clus;
state <= ST_READ_DIR;
end

ST_READ_DIR: begin
state_code <= 4'd6;
sd_sec_read <= 1'b1;
if(sd_sec_read_data_valid && rd_cnt[4:0] == 5'd31) begin
if(name_match) begin
state <= ST_FOUND;
sd_sec_read <= 1'b0;
end
end
if(sd_sec_read_end) begin
sd_sec_read <= 1'b0;
state <= ST_NEXT_SEC;
end
end

ST_NEXT_SEC: begin
state_code <= 4'd7;
if(current_dir_sec - data_area_start_sec > 32'd100) begin
state <= ST_NOT_FOUND;
end else begin
current_dir_sec <= current_dir_sec + 32'd1;
sd_sec_read_addr <= current_dir_sec + 32'd1;
state <= ST_READ_DIR;
end
end

ST_FOUND: begin
state_code <= 4'd8;
scan_found <= 1'b1;
file_size <= cur_dir_size;
file_start_sector <= data_area_start_sec + (cur_dir_clus - 32'd2) * sec_per_clus;
scan_done <= 1'b1;
state <= ST_FOUND;
end

ST_NOT_FOUND: begin
state_code <= 4'd9;
scan_found <= 1'b0;
scan_done <= 1'b1;
state <= ST_NOT_FOUND;
end

default: state <= ST_IDLE;
endcase
end
end

endmodule