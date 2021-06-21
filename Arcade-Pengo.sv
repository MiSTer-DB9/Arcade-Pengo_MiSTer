//============================================================================
//  Arcade: Pengo
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef USE_FB
	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

`ifdef USE_DDRAM
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
`endif

`ifdef USE_SDRAM
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
`endif

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	output	USER_OSD,
	output	[1:0] USER_MODE,
	input	[7:0] USER_IN,
	output	[7:0] USER_OUT,
	input         OSD_STATUS
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[62],status[63],status[61]}; //Assign 3 bits of status (31:29) o (63:61)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6];

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign AUDIO_MIX = 0;

assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2] ) ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] ) ? 8'd3 : 8'd4) : 12'd0;


`include "build_id.v"
localparam CONF_STR = {
	"A.PENGO;;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O7,Flip Screen,Off,On;",
	"OQS,CRT Hsync Adjust,0,1,2,3,4,5,6,7;",
	"OTV,CRT Vsync Adjust,0,1,2,3,4,5,6,7;",
	"-;",
	"oUV,UserIO Joystick,Off,DB9MD,DB15 ;",
	"oT,UserIO Players, 1 Player,2 Players;",
	"-;",
	"O89,Lives,2,3,4,5;",
	"OA,Bonus,30000,50000;",
	"OC,Cabinet,Upright,Cocktail;",
	"OD,Demo Sounds,On,Off;",
	"OE,Test,Off,On;",
	"OFG,Difficulty,Easy,Medium,Hard,Hardest;",
	"-;",
	"R0,Reset;",
	"J1,Kick,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,Start,Select,R,L;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_48;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_48),
	.outclk_1(clk_sys), // 24Mhz
	.locked(pll_locked)
);

reg ce_6m;
always @(posedge clk_sys) begin
	reg [1:0] div;

	div <= div + 1'd1;
	ce_6m <= !div;
end

///////////////////////////////////////////////////

wire [63:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;


wire        ioctl_download;
wire        ioctl_upload;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [15:0] joystick_0_USB, joystick_1_USB;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

// CO S2 S1 F1 U D L R 
wire [31:0] joystick_0 = joydb_1ena ? {joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[9],joydb_1[10],joydb_1[4:0]} : joystick_0_USB;
wire [31:0] joystick_1 = joydb_2ena ? {joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[10],joydb_2[9],joydb_2[4:0]} : joydb_1ena ? joystick_0_USB : joystick_1_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_upload(ioctl_upload),
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),
	.joy_raw(joydb_1[5:0] | joydb_2[5:0]),
);


wire m_up     = joy[3];
wire m_down   = joy[2];
wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_fire   = joy[4];

wire m_up_2     = joy[3];
wire m_down_2   = joy[2];
wire m_left_2   = joy[1];
wire m_right_2  = joy[0];
wire m_fire_2  = joy[5];

wire m_start1 = joy[5];
wire m_start2 = joy[6];
wire m_coin   = joy[7];
wire m_pause   = joy[8];

// PAUSE SYSTEM
reg				pause;									// Pause signal (active-high)
reg				pause_toggle = 1'b0;					// User paused (active-high)
reg [31:0]		pause_timer;							// Time since pause
reg [31:0]		pause_timer_dim = 31'hE4E1C00;	// Time until screen dim (10 seconds @ ~24Mhz)
reg 				dim_video = 1'b0;						// Dim video output (active-high)

assign pause = hs_access | pause_toggle;
assign dim_video = (pause_timer >= pause_timer_dim) ? 1'b1 : 1'b0;

always @(posedge clk_sys) begin
	// User pause toggle
	reg old_pause;
	old_pause <= m_pause;
	if(~old_pause & m_pause) pause_toggle <= ~pause_toggle;
	// Track time paused
	if(pause_toggle)
	begin
		if(pause_timer<pause_timer_dim)
		begin
			pause_timer <= pause_timer + 1'b1;
		end
	end
	else
	begin
		pause_timer <= 1'b0;
	end
end

wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [1:0] b;
wire [7:0] rgb_out = dim_video ? {r >> 1,g >> 1, b >> 1} : {r,g,b};

wire no_rotate = status[2] | direct_video;
wire rotate_ccw = 0;
screen_rotate screen_rotate (.*);

arcade_video #(289,8) arcade_video
(
	.*,

	.clk_video(clk_48),
	.ce_pix(ce_6m),

	.RGB_in(rgb_out),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);


wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

//wire [7:0]m_dip = {status[10] , status[9:8],2'b01,1'b1,status[13],status[14]};
// 30k, no cocktail, no rack test, 5 penguin:
// wire [7:0]m_dip = { 1'b1, 1'b1, 1'b1, 1'b0, 1'b0,1'b0,1'b0,1'b0};
// 50k, no cocktail, no rack test, 5 penguin:
// wire [7:0]m_dip = { 1'b1, 1'b1, 1'b1, 1'b0, 1'b0,1'b0,1'b0,1'b1};
// 30/50, cocktail, no rack test, 5 penguin:
//wire [7:0]m_dip = { 1'b1, 1'b1, 1'b1, 1'b0, 1'b0,1'b1,1'b1,status[10]};

/*
| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|ON |   |   |   |   |   |   |   | Bonus - 30,000*
|OFF|   |   |   |   |   |   |   | Bonus - 50,000
|   |ON |   |   |   |   |   |   | Demo Sounds - ON*
|   |OFF|   |   |   |   |   |   | Demo Sounds - OFF
|   |   |ON |   |   |   |   |   | Cabinet - Upright*
|   |   |OFF|   |   |   |   |   | Cabinet - Cocktail
|   |   |   |OFF|OFF|   |   |   | Lives - 2
|   |   |   |ON |OFF|   |   |   | Lives - 3*
|   |   |   |OFF|ON |   |   |   | Lives - 4
|   |   |   |ON |ON |   |   |   | Lives - 5
|   |   |   |   |   |OFF|   |   | Rack Test - Off*
|   |   |   |   |   |ON |   |   | Rack Test - On
|   |   |   |   |   |   |OFF|OFF| Difficulty - Easy
|   |   |   |   |   |   |ON |OFF| Difficulty - Medium *
|   |   |   |   |   |   |OFF|ON | Difficulty - Hard
|   |   |   |   |   |   |ON |ON | Difficulty - Hardest
*/

wire reset = RESET | status[0] | buttons[1] | ioctl_download;
wire rom_download = ioctl_download & !ioctl_index;
wire [7:0]m_dip = { ~status[16:15], ~status[14],~status[9:8],status[12],status[13],status[10]};

pengo pengo
(
	.O_VIDEO_R(r),
	.O_VIDEO_G(g),
	.O_VIDEO_B(b),
	.O_HSYNC(hs),
	.O_VSYNC(vs),
	.O_HBLANK(hblank),
	.O_VBLANK(vblank),

	.flip_screen(status[7]),
	.h_offset(status[28:26]),
	.v_offset(status[31:29]),

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),

	.O_AUDIO(audio),

	.in0(~{m_fire,1'b0,m_coin,1'b0, m_right,m_left,m_down,m_up}),
	.in1(~{m_fire_2, m_start2, m_start1,1'b0,m_right_2,m_left_2,m_down_2,m_up_2}),

	.dipsw1(m_dip),

	//.dipsw1(8'b11100000),
	.dipsw2(8'b11001100),

	.reset(reset),
	.clk(clk_sys),
	.ena_6(ce_6m),

	.hs_address(hs_address),
	.hs_data_out(ioctl_din),
	.hs_data_in(hs_data_in),
	.hs_write(hs_write),
	.hs_access(hs_access),

	.pause(pause)
);

// HISCORE SYSTEM
// --------------
wire [11:0]hs_address;
wire [7:0]hs_data_in;
wire hs_write;
wire hs_access;

hiscore #(
	.HS_ADDRESSWIDTH(12),
	.CFG_ADDRESSWIDTH(2),
	.CFG_LENGTHWIDTH(2),
	.DELAY_CHECKWAIT(20'h4E20)
) hi (
	.clk(clk_sys),
	.reset(reset),
	.delay(1'b1),
	.ioctl_upload(ioctl_upload),
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ram_address(hs_address),
	.data_to_ram(hs_data_in),
	.ram_write(hs_write),
	.ram_access(hs_access)
);

endmodule
