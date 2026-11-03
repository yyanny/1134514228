module osd_overlay (
    input               clk,        // 像素时钟 video_clk
    input               rst_n,      // 低有效复位
    input       [9:0]   pix_x,      // 当前像素X坐标
    input       [9:0]   pix_y,      // 当前像素Y坐标
    input       [23:0]  rgb_in,     // 原始图像RGB输入
    input               osd_en,     // OSD总开关，1=显示，0=不显示
    input       [7:0]   osd_data,   // 要显示的数字，0~99
    output  reg [23:0]  rgb_out     // 叠加字幕后的RGB输出
);

// ===================== 配置参数 =====================
parameter OSD_X_START = 10'd30;   // 字幕左上角X坐标
parameter OSD_Y_START = 10'd30;   // 字幕左上角Y坐标
parameter CHAR_NUM    = 2'd2;     // 显示字符个数，2位数字
parameter CHAR_WIDTH  = 4'd8;     // 单个字符宽度 8像素
parameter CHAR_HEIGHT = 5'd16;    // 单个字符高度 16像素
// ====================================================

// 8x16 ASCII 字模，仅数字 0-9，每行8bit，高位在左
reg [7:0] font_rom [0:159];
initial begin
    // 0
    font_rom[0]  = 8'h00;  font_rom[1]  = 8'h3E;
    font_rom[2]  = 8'h51;  font_rom[3]  = 8'h49;
    font_rom[4]  = 8'h45;  font_rom[5]  = 8'h43;
    font_rom[6]  = 8'h3E;  font_rom[7]  = 8'h00;
    font_rom[8]  = 8'h00;  font_rom[9]  = 8'h00;
    font_rom[10] = 8'h00;  font_rom[11] = 8'h00;
    font_rom[12] = 8'h00;  font_rom[13] = 8'h00;
    font_rom[14] = 8'h00;  font_rom[15] = 8'h00;
    // 1
    font_rom[16] = 8'h00;  font_rom[17] = 8'h42;
    font_rom[18] = 8'h7F;  font_rom[19] = 8'h40;
    font_rom[20] = 8'h40;  font_rom[21] = 8'h00;
    font_rom[22] = 8'h00;  font_rom[23] = 8'h00;
    font_rom[24] = 8'h00;  font_rom[25] = 8'h00;
    font_rom[26] = 8'h00;  font_rom[27] = 8'h00;
    font_rom[28] = 8'h00;  font_rom[29] = 8'h00;
    font_rom[30] = 8'h00;  font_rom[31] = 8'h00;
    // 2
    font_rom[32] = 8'h00;  font_rom[33] = 8'h62;
    font_rom[34] = 8'h51;  font_rom[35] = 8'h49;
    font_rom[36] = 8'h49;  font_rom[37] = 8'h49;
    font_rom[38] = 8'h46;  font_rom[39] = 8'h00;
    font_rom[40] = 8'h00;  font_rom[41] = 8'h00;
    font_rom[42] = 8'h00;  font_rom[43] = 8'h00;
    font_rom[44] = 8'h00;  font_rom[45] = 8'h00;
    font_rom[46] = 8'h00;  font_rom[47] = 8'h00;
    // 3
    font_rom[48] = 8'h00;  font_rom[49] = 8'h22;
    font_rom[50] = 8'h41;  font_rom[51] = 8'h49;
    font_rom[52] = 8'h49;  font_rom[53] = 8'h49;
    font_rom[54] = 8'h36;  font_rom[55] = 8'h00;
    font_rom[56] = 8'h00;  font_rom[57] = 8'h00;
    font_rom[58] = 8'h00;  font_rom[59] = 8'h00;
    font_rom[60] = 8'h00;  font_rom[61] = 8'h00;
    font_rom[62] = 8'h00;  font_rom[63] = 8'h00;
    // 4
    font_rom[64] = 8'h00;  font_rom[65] = 8'h18;
    font_rom[66] = 8'h14;  font_rom[67] = 8'h12;
    font_rom[68] = 8'h7F;  font_rom[69] = 8'h10;
    font_rom[70] = 8'h00;  font_rom[71] = 8'h00;
    font_rom[72] = 8'h00;  font_rom[73] = 8'h00;
    font_rom[74] = 8'h00;  font_rom[75] = 8'h00;
    font_rom[76] = 8'h00;  font_rom[77] = 8'h00;
    font_rom[78] = 8'h00;  font_rom[79] = 8'h00;
    // 5
    font_rom[80] = 8'h00;  font_rom[81] = 8'h27;
    font_rom[82] = 8'h45;  font_rom[83] = 8'h45;
    font_rom[84] = 8'h45;  font_rom[85] = 8'h45;
    font_rom[86] = 8'h39;  font_rom[87] = 8'h00;
    font_rom[88] = 8'h00;  font_rom[89] = 8'h00;
    font_rom[90] = 8'h00;  font_rom[91] = 8'h00;
    font_rom[92] = 8'h00;  font_rom[93] = 8'h00;
    font_rom[94] = 8'h00;  font_rom[95] = 8'h00;
    // 6
    font_rom[96] = 8'h00;  font_rom[97] = 8'h3C;
    font_rom[98] = 8'h4A;  font_rom[99] = 8'h49;
    font_rom[100]= 8'h49;  font_rom[101]= 8'h49;
    font_rom[102]= 8'h30;  font_rom[103]= 8'h00;
    font_rom[104]= 8'h00;  font_rom[105]= 8'h00;
    font_rom[106]= 8'h00;  font_rom[107]= 8'h00;
    font_rom[108]= 8'h00;  font_rom[109]= 8'h00;
    font_rom[110]= 8'h00;  font_rom[111]= 8'h00;
    // 7
    font_rom[112]= 8'h00;  font_rom[113]= 8'h01;
    font_rom[114]= 8'h71;  font_rom[115]= 8'h09;
    font_rom[116]= 8'h05;  font_rom[117]= 8'h03;
    font_rom[118]= 8'h00;  font_rom[119]= 8'h00;
    font_rom[120]= 8'h00;  font_rom[121]= 8'h00;
    font_rom[122]= 8'h00;  font_rom[123]= 8'h00;
    font_rom[124]= 8'h00;  font_rom[125]= 8'h00;
    font_rom[126]= 8'h00;  font_rom[127]= 8'h00;
    // 8
    font_rom[128]= 8'h00;  font_rom[129]= 8'h36;
    font_rom[130]= 8'h49;  font_rom[131]= 8'h49;
    font_rom[132]= 8'h49;  font_rom[133]= 8'h49;
    font_rom[134]= 8'h36;  font_rom[135]= 8'h00;
    font_rom[136]= 8'h00;  font_rom[137]= 8'h00;
    font_rom[138]= 8'h00;  font_rom[139]= 8'h00;
    font_rom[140]= 8'h00;  font_rom[141]= 8'h00;
    font_rom[142]= 8'h00;  font_rom[143]= 8'h00;
    // 9
    font_rom[144]= 8'h00;  font_rom[145]= 8'h06;
    font_rom[146]= 8'h49;  font_rom[147]= 8'h49;
    font_rom[148]= 8'h49;  font_rom[149]= 8'h29;
    font_rom[150]= 8'h1E;  font_rom[151]= 8'h00;
    font_rom[152]= 8'h00;  font_rom[153]= 8'h00;
    font_rom[154]= 8'h00;  font_rom[155]= 8'h00;
    font_rom[156]= 8'h00;  font_rom[157]= 8'h00;
    font_rom[158]= 8'h00;  font_rom[159]= 8'h00;
end

// 内部信号
reg [3:0]   char_index;     // 当前第几个字符 0/1
reg [3:0]   char_line;      // 当前字符的第几行 0~15
reg [2:0]   char_dot;       // 当前字符的第几列 0~7
reg [7:0]   char_code;      // 当前字符编码 0~9
reg [7:0]   font_line_data; // 当前行字模数据
reg         dot_valid;      // 当前像素是否点亮

// 1. 计算字符位置、行列偏移
always @(*) begin
    if (osd_en
        && pix_x >= OSD_X_START
        && pix_x <  OSD_X_START + CHAR_NUM * CHAR_HEIGHT
        && pix_y >= OSD_Y_START
        && pix_y <  OSD_Y_START + CHAR_WIDTH) begin
        char_index = (pix_x - OSD_X_START) / CHAR_HEIGHT;  // 第几个字符
        char_line   = (pix_x - OSD_X_START) % CHAR_HEIGHT;  // 字符内第几列
        char_dot  = pix_y - OSD_Y_START;                 // 字符内第几行
    end else begin
        char_index = 4'd0;
        char_line  = 4'd0;
        char_dot   = 3'd0;

    end
end

// 2. 取字模数据
always @(*) begin
    // 十位、个位拆分
    if (char_index == 0)
        char_code = osd_data / 8'd10;
    else
        char_code = osd_data % 8'd10;
    
    // 字模地址 = 字符编号*16 + 行号
    font_line_data = font_rom[char_code * 5'd16 + char_line];
end

// 3. 像素点判断，高位在左
always @(*) begin
    dot_valid = font_line_data[char_dot];
end

// 4. 最终RGB输出
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rgb_out <= 24'd0;
    end else begin
        if (osd_en && dot_valid)
            rgb_out <= 24'h000000;  // 白色字体
        else
            rgb_out <= rgb_in;      // 原图直通
    end
end

endmodule
