// vim: ts=4:
// A 2x4Lane MIPI DSI TX test pattern generator to drive 8 Gbit/s (1800x1800 RGB24 LCD module @ 100Hz)
//
// Copyright (C) 2026 Eric Pearson
//
// Lattice Crosslink FPGA
// This design directly instantiates the 2 hardened mipi_dsi_tx cores
// Outputs 2x4Lane mipi DSI streams:
// Manufactures LCD startup sequence.
// RGB Test pattern.

module chip_top (
	// System control
	clkin, 
	// MIPI DSI TX port
	l_clk_n,
	l_clk_p,
	l_data_n, 
	l_data_p,
	r_clk_n,
	r_clk_p,
	r_data_n, 
	r_data_p,
	// LCD Control Lines
	lcd_en_vcc,
	lcd_reset,
	lcd_pwm,
	// Test I/O
	led0, 	// UL Led (D2) -- 2Hz Blink *-*-----
	led1,	// LR Led (D3) -- reset output
	led2,	// UR Led (D4) -- test blinker0
	led3,	// LL Led (D5) -- test blinker1
	key0, 	// L button (K2) -- tied to blinker 0 for now.
	key1, 	// R Button (K1) -- pushbutton reset
	// fpga uart
	fpga_txd,
	fpga_rxd
	);
	
	////////////////////////
	// Declare I/O
	////////////////////////
	
	// System
	input wire clkin; // from 50 hz Osc

// debug
	output wire led0, led1, led2, led3;
	input wire key0, key1;
	output wire fpga_txd;
	input wire fpga_rxd;
	// LCD Controls
	output wire lcd_en_vcc, lcd_reset;
	input wire lcd_pwm;
	// MIPI DSI Tx
	inout wire l_clk_n, l_clk_p;
	inout wire [3:0] l_data_n, l_data_p;
	inout wire r_clk_n, r_clk_p;
	inout wire [3:0] r_data_n, r_data_p;

	
	/////////////////////////
	// Clock and Reset
	/////////////////////////
	
	// 50 hz clkin is pin driven from external 50 Mhz Osc
	
	// 62.5 Mhz System clock is the HSbyteclk from the mipi cores.
	wire clk, clkr; // these should be exaclty in phase, with just jitter (no fifo needed?)

	// Reset Strategy
	//
	// As this is an fpga we config determines start state,
	// however we'd like a functional syncronous global 'reset'
	// At fpgra startup, reset remains asserted for 256 clkin_cycles
	// External pushbutton K1 (left button) also generates a 100 Ms reset

	// fpga config reset
	reg [7:0] cfg_count; // init to zero at fpga config
	always @( posedge clk )
		cfg_count <= ( cfg_count == 8'hFF ) ? 8'hFF : cfg_count + 1;
	
	// ext (pushbutton) reset (active low key1)
	// not triggered during chip config
	
	localparam MSEC = 62500;
	reg [23:0] ext_count;
	always @( posedge clk ) 
		ext_count <= ( !key1 ) ? 100*MSEC : 
		             ( ext_count != 0 ) ? ext_count - 1 : 0;
		
	// global sync reset
	reg reset;
	always @(posedge clk) 
		reset <= ( cfg_count != 8'hff || ext_count != 0 ) ? 1'b1 : 1'b0;
		
	// output reset as LED
	assign led1 = reset;

	////////////////////////
	// Uart - sync loopback
	////////////////////////
	
	reg [7:0] uart_pipe;
	reg txd;
	always @(posedge clk) 
		{ txd, uart_pipe } <= { uart_pipe, fpga_rxd };
	assign fpga_txd = txd;
	
	///////////////////////
	// Mini LED 'scopes
	///////////////////////
	
	// A logic probe drives an LED at 4Hz if it see's any changes in the monitored signal
	// one for each of LED2,3
	
	reg [3:0] t0del, t1del;
	reg t0flag, t1flag;
	reg [23:0] t0count, t1count;
	always @(posedge clk) begin
			t0del <= { t0del[2:0], lcd_pwm }; 	// input 0
			t1del <= { t1del[2:0], key0 };		// input 1
			t0flag <= (t0del[3]^t0del[2]) | (( t0count == 0 && !t0flag ) ? 1'b0 : t0flag ); // latch flag
			t1flag <= (t1del[3]^t1del[2]) | (( t1count == 0 && !t1flag ) ? 1'b0 : t1flag ); // latch flag
			t0count <= ( t0count == 0 && t0flag ) ? 'h400000 : ( t0count != 0 ) ? t0count - 1 : 0;
			t1count <= ( t1count == 0 && t1flag ) ? 'h400000 : ( t1count != 0 ) ? t1count - 1 : 0;
	end
	
	assign led2 = t0count[23] ^ t0del[3];
	assign led3 = t1count[23] ^ t1del[3];
	

	/////////////////////////
	// 2x4 MIPI_DSI TX
	/////////////////////////

	wire clk_txlpen, clk_txlpn, clk_txlpp;
	wire clk_txhsen, clk_txhsgate;
	wire d0_txlpen, d0_txlpn, d0_txlpp; 
	wire d0_txhsen;
	wire [63:0] l_tx_data, r_tx_data;
	
	mipi_dsi_tx i_txl (
		// Bidir ports
		.clk_n	( l_clk_n ), 
		.clk_p	( l_clk_p ), 
		.data_n	( l_data_n[3:0] ), 
    	.data_p	( l_data_p[3:0] ), 
		
		// RX LP Ports
		.d0_rxlpn	( ), 
		.d0_rxlpp	( ), 
		
		// TX LP ports
		.d0_txlpen	( d0_txlpen ),
    	.d0_txlpn	( d0_txlpn ), 
		.d1_txlpn	( d0_txlpn ), 
		.d2_txlpn	( d0_txlpn ), 
		.d3_txlpn	( d0_txlpn ), 
		.d0_txlpp	( d0_txlpp ), 
		.d1_txlpp	( d0_txlpp ), 
		.d2_txlpp	( d0_txlpp ), 
    	.d3_txlpp	( d0_txlpp ), 		
		
		// TX HS ports
		.d0_txhsen	( d0_txhsen ), 
		.txdata	( l_tx_data[63:0] ),	
		.txhsbyteclk( clk ), // user clock
		
		// PLL Ports
		.refclk		( clkin ), 
		.lock		(  ), 
		.pd_pll		( 1'b0 ), 
		.usrstdby	( 1'b0 ), 
		
		// HS Clocking
		.clk_txhsen		( clk_txhsen ), 
		.clk_txhsgate	( clk_txhsgate ), // polarity??
		
		// LS Clocking
		.clk_txlpen	( clk_txlpen ), 
    	.clk_txlpn 	( clk_txlpn ), 
		.clk_txlpp	( clk_txlpp )
	);

	
	mipi_dsi_tx i_txr (
		// Bidir ports
		.clk_n	( r_clk_n ), 
		.clk_p	( r_clk_p ), 
		.data_n	( r_data_n[3:0] ), 
    	.data_p	( r_data_p[3:0] ), 
		
		// RX LP Ports
		.d0_rxlpn	( ), 
		.d0_rxlpp	( ), 
		
		// TX LP ports
		.d0_txlpen	( d0_txlpen ),
    	.d0_txlpn	( d0_txlpn ), 
		.d1_txlpn	( d0_txlpn ), 
		.d2_txlpn	( d0_txlpn ), 
		.d3_txlpn	( d0_txlpn ), 
		.d0_txlpp	( d0_txlpp ), 
		.d1_txlpp	( d0_txlpp ), 
		.d2_txlpp	( d0_txlpp ), 
    	.d3_txlpp	( d0_txlpp ), 		
		
		// TX HS ports
		.d0_txhsen	( d0_txhsen ), 
		.txdata	( r_tx_data[63:0] ),
		.txhsbyteclk( clkr ), // phase locked to clk?
		
		// PLL Ports
		.refclk		( clkin ), 
		.lock		(  ), 
		.pd_pll		( 1'b0 ), 
		.usrstdby	( 1'b0 ), 
		
		// HS Clocking
		.clk_txhsen		( clk_txhsen ), 
		.clk_txhsgate	( clk_txhsgate ), 
		
		// LS Clocking
		.clk_txlpen	( clk_txlpen ), 
    	.clk_txlpn 	( clk_txlpn ), 
		.clk_txlpp	( clk_txlpp )
	);
	
	///////////////////////////////
	// LCD Video Mipi Formating
	///////////////////////////////
	
	wire [95:0] left_rgb, right_rgb;
	wire [2:0] phase;
	wire hsync, vsync, active;
	wire [3:0] ovl, ovl0, ovl1, ovl2;
	mipi_format_lcd i_video (
		// System
		.clk	( clk ),
		.reset	( reset ),
		// LCD Info inputs
		.lcd_te( 1'b1 ),
		.lcd_pwm( lcd_pwm ),
		.lcd_id( 2'b01 ),
		// LCD control outputs
		.lcd_reset( lcd_reset ),
		.lcd_pn2ptx( ),
		.lcd_en_vsp( ),
		.lcd_en_vsn( ),
		.lcd_en_vcc( lcd_en_vcc ),
		// Mipi Control Outputs
		.txlpen	( d0_txlpen ),
		.txlpn	( d0_txlpn ),
		.txlpp	( d0_txlpp ),
		.txhsen	( d0_txhsen ),
		.clk_txhsen		( clk_txhsen ), 
		.clk_txhsgate	( clk_txhsgate ), 
		.clk_txlpen		( clk_txlpen ), 
    	.clk_txlpn 		( clk_txlpn ), 
		.clk_txlpp		( clk_txlpp ),
		// Mipi Tx Data
		.l_data ( l_tx_data[63:0] ),
		.r_data ( r_tx_data[63:0] ),
		// Video Sync output
		.vsync ( vsync ),
		.hsync ( hsync ),
		.active( active ),
		.phase ( phase[2:0] ),
		// RGB Inputs
		.l_rgb	( left_rgb[95:0] ),
		.r_rgb	( right_rgb[95:0] | {{24{ovl[3]}},{24{ovl[2]}},{24{ovl[1]}},{24{ovl[0]}}} )	// right has overlay	
	); 
	
	///////////////////////////////
	// LCD Test Pattern Generator
	///////////////////////////////

    test_pattern_lcd i_test_pat (
		// system
		.clk	( clk ),
		.reset  ( reset ),
		// Video sync input
		.vsync	( vsync ),
		.hsync	( hsync ),
		.active ( active ),
		.phase	( phase ),   
		// RGB Outputs
		.rgb_left	( left_rgb[95:0]  ),
		.rgb_right	( right_rgb[95:0] )
	);

	wire [7:0] char_x, char_y;
	wire [63:0] hex_char;
	hex_font4 i_font (
		// system
		.clk	( clk ),
		.reset  ( reset ),
		// Video sync input
		.vsync	( vsync ),
		.hsync	( hsync ),
		.active ( active ),
		.phase	( phase ),   
		// Char location and data
		.char_x ( char_x ),
		.char_y ( char_y ),
		.hex_char ( hex_char )
	);

	// Commit overlay, sh watermark.sh after pull before building
	commit_overlay i_com_ovl( clk, reset, vsync, hsync, active, phase, ovl0, led0 ); 

	
	// Frame counter hex overlay
	reg [31:0] frame_count;
	always @(posedge clk) begin
		frame_count <= ( reset ) ? 0 : ( vsync ) ? frame_count + 1 : frame_count;
	end
	hex_overlay4 #( 8 ) i_hex1( clk, reset, char_x, char_y, hex_char, frame_count, 8'd4, 8'd4, ovl1 );
	
	// Clock counter hex overlay 
	reg [31:0] clk_count;
	always @(posedge clk) 
		clk_count <= ( reset ) ? 0 : clk_count + 1;
	hex_overlay4 #( 8 ) i_hex2( clk, reset, char_x, char_y, hex_char, clk_count, 8'd4, 8'd5, ovl2 );
	
	// Or together the overlays
	// Toggle debug overlay HERE, synthesis removed unsed logic
	//assign ovl = ovl0; // just commit overlay rom, small (+3%) try to always keep!
	assign ovl = ovl0 | ovl1 | ovl2; // add dynamic debug overlays, largish (cost=14%), can be useful

endmodule


// Generate format RGB video for LCD display 
// To drive 2x4 MIPI DSI TX cores.
module mipi_format_lcd (
		// System
		clk,
		reset,
		// LCD status 
		lcd_te,
		lcd_pwm,
		lcd_id,
		// LCD control outputs
		lcd_reset,
		lcd_pn2ptx,
		lcd_en_vsp,
		lcd_en_vsn,
		lcd_en_vcc,
		// Mipi Control Outputs
		txlpen,
		txlpn,
		txlpp,
		txhsen,
		clk_txhsen,
		clk_txhsgate,
		clk_txlpen,
    	clk_txlpn,
		clk_txlpp,
		// Mipi Tx Data
		l_data,
		r_data,
		// Video Sync output
		vsync,
		hsync,
		active,
		phase,
		// RGB Inputs
		l_rgb,
		r_rgb
	);

	// Video format parameters, derived from LCD datasheet
	parameter VID_HEIGHT 	= 1600;
	parameter VID_WIDTH 	= 1600;
	parameter VID_VBACK 	= 150;
	parameter VID_VFRONT	= 29;
	parameter VID_VTOTAL	= 1779;
	parameter VID_HFRONT    = 45; // cycles
	parameter VID_HBACK     = 45; // cycles
	parameter VID_LINE 		= 390; // number of input words into 16:1 mipi interface per line
	parameter VID_ACTIVE 	= 300; // number of cycles active
	parameter VID_LAT    	= 3; // Number of cycles (mult of 3) active is early for video generation 

	// Declare I/O
	input wire clk;
	input wire reset;
	input wire lcd_te, lcd_pwm;
	input wire [1:0] lcd_id;
	output wire lcd_reset, lcd_pn2ptx;
	output wire lcd_en_vsp, lcd_en_vsn, lcd_en_vcc;
	output wire txlpen,	txlpn, txlpp, txhsen;
	output wire clk_txhsen,	clk_txhsgate, clk_txlpen, clk_txlpn, clk_txlpp;
	output wire vsync, hsync, active;
	output wire [2:0] phase; 
	input wire [4*3*8-1:0] l_rgb, r_rgb; 
	output wire [63:0] l_data, r_data; 


	// 1 sec Initialization counter at 62.5 Mhz
	localparam MSEC =  62500; // 1 ms
	reg [25:0] init_count;
	always @(posedge clk) 
		init_count <= ( reset ) ? 26'h0 : ( init_count == 1000*MSEC ) ? 1000*MSEC : init_count + 1;

	// Startup Sequence 
	wire hs_enable, ini_active, vid_en;
	assign  lcd_en_vcc 		= ( init_count > 1*MSEC ) ? 1'b1 : 1'b0;
	assign  lcd_en_vsp 		= ( init_count > 2*MSEC ) ? 1'b1 : 1'b0;
	assign  lcd_en_vsn 		= ( init_count > 3*MSEC ) ? 1'b1 : 1'b0;
	assign  lcd_reset 	    = ( init_count > 6*MSEC ) ? 1'b1 : 1'b0;
	assign	hs_enable 		= ( init_count > 26*MSEC ) ? 1'b1 : 1'b0; // Transition to HS mode
	assign  ini_active		= ( init_count > 26*MSEC + 39 ) ? 1'b1: 1'b0; // Send lcd init seq
	assign  vid_en    		= ( init_count > 26*MSEC + 39+31 ) ? 1'b1: 1'b0; // start video

	// first entry is reset state, final entry is runningstate
	// Clk lane startup
	//                    lp11,lp01,lp00,  clk hs00     ,clk start
	wire [0:39] clpen = 40'b1_1111_1111_000000000000000_0_0000_0000_000000_0;
	wire [0:39] clpdp = 40'b1_0000_0000_000000000000000_0_0000_0000_000000_0;
	wire [0:39] clpdn = 40'b1_1111_0000_000000000000000_0_0000_0000_000000_0;
	wire [0:39] chsen = 40'b0_0000_0000_111111111111111_1_1111_1111_111111_1;
	wire [0:39] chsgt = 40'b0_0000_0000_000000000000000_1_1111_1111_111111_1;
	// Data Lane startup                         data lp11,lp01,lp00,hs0   ,hs start
	wire [0:39] dlpen = 40'b1_1111_1111_111111111111111_1_1111_1111_000000_0;
	wire [0:39] dlpdp = 40'b1_1111_1111_111111111111111_1_0000_0000_000000_0;
	wire [0:39] dlpdn = 40'b1_1111_1111_111111111111111_1_1111_0000_000000_0;
	wire [0:39] dhsen = 40'b0_0000_0000_000000000000000_0_0000_0000_111111_1;


	// LP11 to MS transition takes place over 40 cycles
	reg [5:0] start_cnt;
	always @(posedge clk)
		start_cnt <= ( reset ) ? 0 : ( start_cnt == 39 ) ? 39 : ( hs_enable ) ? start_cnt + 1 : 0;

	// Connect CLK lane controls
	assign clk_txlpen 	= clpen[start_cnt];
	assign clk_txlpp 	= clpdp[start_cnt];
	assign clk_txlpn 	= clpdn[start_cnt];
	assign clk_txhsen 	= chsen[start_cnt];
	assign clk_txhsgate = chsgt[start_cnt];
	// Connect Data lane controls
	assign  txlpen 		= dlpen[start_cnt];
	assign  txlpp 		= dlpdp[start_cnt]; 
	assign  txlpn 		= dlpdn[start_cnt]; 
	assign  txhsen    	= dhsen[start_cnt];

	
	// constant array of init data size 32wx64b, to be folded into lut
	function [2047:0] ini_data;
		input right;
		ini_data = {
		// 1st 64 bit word completes the LP to HS transition
		// continue zero's to align
		{4{8'h00}}, 
		// a single synch 00011101 byte down each of 4 lanes
		{4{8'hB8}},
		
		/////////////////////////////////////////////
		// Custom LCD initialization, up to 30 words 
		/////////////////////////////////////////////
		// MFG Commands 
		// <redacted>
		// Alignment NOP to get to 64b boundary
	    // Crc lens: 2,2,10,5,5,9,2,17,2,8,6,2,3,2,2,2, needs 9 bytes(crc3) to align at 23 words
		ecc( { 8'h09, 8'h04, 8'h00} ), crc4( {4{8'h00}} ),

		// Padd to allocated 30 Init words / future expansion
		ecc( { 8'h09, 8'h02, 8'h00} ), crc2( {2{8'h00}} ), // 64b word
		ecc( { 8'h09, 8'h02, 8'h00} ), crc2( {2{8'h00}} ), // 64b word
		ecc( { 8'h09, 8'h02, 8'h00} ), crc2( {2{8'h00}} ), // 64b word
		ecc( { 8'h09, 8'h02, 8'h00} ), crc2( {2{8'h00}} ), // 64b word
		ecc( { 8'h09, 8'h02, 8'h00} ), crc2( {2{8'h00}} ), // 64b word
		ecc( { 8'h09, 8'h02, 8'h00} ), crc2( {2{8'h00}} ), // 64b word
		ecc( { 8'h09, 8'h02, 8'h00} ), crc2( {2{8'h00}} ), // 64b word
		// END of 30 iniots  words
		/////////////////////////////////////////////

		/////////////////////////////////////////////
		// last init word is display-on, sleep off 
		/////////////////////////////////////////////
	
		ecc( { 8'h05, 8'h29, 8'h00 } ), // Set Display on
		ecc( { 8'h05, 8'h11, 8'h00 } )  // Exit sleep mode, MUST be immediatly followed by VSYNC

		// END of 32 Words
		};
	endfunction
	
	wire [2047:0] l_ini_data, r_ini_data;
	assign l_ini_data = ini_data( 0 );
	assign r_ini_data = ini_data( 1 );
	reg [63:0] l_cmd_rom [0:31]; // master (left) in little endian
	reg [63:0] r_cmd_rom [0:31]; // subordinate (right) in little endian
	integer ii, jj;
	always @(l_ini_data, r_ini_data) begin
		for( ii = 0; ii < 32; ii = ii + 1 )
			for( jj = 0; jj < 8; jj = jj + 1 ) begin
				l_cmd_rom[31-ii][jj*8+7-:8] = l_ini_data[ii*64+63-jj*8-:8];
				r_cmd_rom[31-ii][jj*8+7-:8] = r_ini_data[ii*64+63-jj*8-:8];
			end
	end

	// Generate 32 bit init sequence
	reg [4:0] ini_addr;
	always @(posedge clk) begin
		ini_addr <= ( reset ) ? 5'h0 : (ini_addr == 31) ? 31 : ( ini_active ) ? ini_addr + 1 : 0;
	end

	wire [63:0] nop;
	assign nop = swap8( { ecc( { 8'h09, 8'h02, 8'h00} ), crc4( {2{8'h00}} ) } );
	wire [63:0] l_cmd, r_cmd;
	assign l_cmd = l_cmd_rom[ini_addr];
	assign r_cmd = r_cmd_rom[ini_addr];


	// Video Timing Geneator
	reg [2:0] ph;
	reg [8:0] xpos;
	reg [10:0] ypos;
	reg [4:0] frame; // frame count clippe d to 15
	always @(posedge clk) begin
		if( reset || !vid_en ) begin
			xpos <= 9'd0;
			ypos <= 11'd0;
			frame <= 4'd0;
			ph <= 0;
		end else begin
			ph <= ( xpos == VID_LINE - 1 ) ? 3'b001 : { ph[1:0], ph[2] };
			xpos <= ( xpos == VID_LINE - 1 ) ? 9'd0 : xpos + 9'd1;
			ypos <= ( xpos == VID_LINE - 1 && ypos == VID_VTOTAL - 1 ) ? 11'd0 :
			        ( xpos == VID_LINE - 1 ) ? ypos + 11'h1 : ypos;
			frame <= ( frame == 4'd15 ) ? 4'd15 : 
                     ( xpos == VID_LINE - 1 && ypos == VID_VTOTAL - 1 ) ? frame + 4'd1 : frame;
		end
	end
	
	// Internal sync signals
	wire hactive, vactive;
	assign vactive = ( vid_en && ypos >= VID_VBACK && ypos < VID_VBACK + VID_HEIGHT ) ? 1'b1 : 1'b0;
	assign hactive = ( vid_en && xpos >= VID_HFRONT && xpos < VID_HBACK + VID_ACTIVE ) ? 1'b1 : 1'b0;	
	
	// video sync outputs
	assign phase = ph;
	assign vsync = ( xpos == 0 && ypos == 0 && vid_en ) ? 1'b1 : 1'b0;
	assign hsync = ( xpos == 0 && vid_en ) ? 1'b1 : 1'b0;
	assign active = ( vactive && xpos >= VID_HFRONT - VID_LAT && xpos < VID_HBACK + VID_ACTIVE - VID_LAT ) ? 1'b1 : 1'b0;
					 
	// Register RGB inputs
	// 2:3 rgb:mipi conversion logic
	reg [96:0] lreg, rreg;
	always @(posedge clk) begin
		lreg <= l_rgb;
		rreg <= r_rgb;
	end
	
	// Pack RGB inputs into mipi words
	// first word of RGB data arrives aligned with h_active, whith data on ph0, ph1
	wire [63:0] l_prgb, r_prgb;
	assign l_prgb[63:0] = ( ph[0] ) ? l_rgb[63:0] : ( ph[1] ) ? { l_rgb[31:0], rreg[95:64] } : lreg[95:32];
	assign r_prgb[63:0] = ( ph[0] ) ? r_rgb[63:0] : ( ph[1] ) ? { r_rgb[31:0], lreg[95:64] } : rreg[95:32];
	// Video MIPI words
	wire [63:0] dsi_vss, dsi_hss, dsi_post_short;
	wire [63:0] dsi_disp_on, dsi_sequence, dsi_protect;
	wire [63:0] dsi_post_vid, dsi_bp, dsi_null;
	wire [63:0] dsi_pre_rgb_0, dsi_pre_rgb_1, dsi_post_rgb;
	wire [127:0] dsi_pre_rgb;
	
	assign dsi_bp 			= swap8( { ecc( { 8'h19, 8'h02, 8'h00 } ), crc2( { 8'h00, 8'h00 } ) } );
	assign dsi_null 		= swap8( { ecc( { 8'h09, 8'h02, 8'h00 } ), crc2( { 8'h00, 8'h00 } ) } );
	assign dsi_vss          = swap8( { ecc( { 8'h01, 8'h00, 8'h00 } ), ecc( { 8'h19, 8'h06, 8'h00 } ) } );
	assign dsi_hss          = swap8( { ecc( { 8'h21, 8'h00, 8'h00 } ), ecc( { 8'h19, 8'h06, 8'h00 } ) } );
	assign dsi_post_short	= swap8( crc6( {6{8'h00}} ) );
	assign dsi_pre_rgb      = { ecc( { 8'h19, 8'h06, 8'h00} ), crc6( {6{8'h00}} ), ecc( { 8'h3E, 8'h84, 8'h03} ) }; 
	assign dsi_pre_rgb_0	= swap8( dsi_pre_rgb[127:64] );
	assign dsi_pre_rgb_1	= swap8( dsi_pre_rgb[63:0] );
	assign dsi_post_rgb		= swap8( { 16'h0000, ecc( { 8'h19, 8'h00, 8'h00 } ), 16'hffff } );
	assign dsi_sequence		= swap8( { ecc( { 8'h29, 8'h02, 8'h00} ), crc2( { 8'hD6, 8'h80 } ) } );
	assign dsi_protect		= swap8( { ecc( { 8'h29, 8'h02, 8'h00} ), crc2( { 8'hB0, 8'h03 } ) } );

	// Calc CRC (TODO: set to 16'h0000 and see if it works (saves 15% of chip area)
	wire [15:0] l_crc, r_crc;
	vid_crc i_l_crc( .reset(reset), .clk(clk), .en( hactive & vactive ), .data( l_prgb ), .crc( l_crc ) );
	vid_crc i_r_crc( .reset(reset), .clk(clk), .en( hactive & vactive ), .data( r_prgb ), .crc( r_crc ) );	
	// Build Video Frame data
	reg [63:0] l_vid, r_vid;
	always @(posedge clk) begin
		if( vid_en ) begin
			if( xpos == 0 ) begin
				l_vid <= ( ypos == 0 ) ? dsi_vss : dsi_hss;
				r_vid <= ( ypos == 0 ) ? dsi_vss : dsi_hss;
			end else if( xpos == 1 ) begin
				l_vid <= dsi_post_short;
				r_vid <= dsi_post_short;
			end else if( frame == 7 && ypos == 0 && xpos == 8 ) begin
				l_vid <= dsi_sequence;
				r_vid <= dsi_sequence;
			end else if( frame == 7 && ypos == 0 && xpos == 8+1 ) begin
				l_vid <= dsi_protect;
				r_vid <= dsi_protect;
			end else if( vactive ) begin
				if( xpos == VID_HFRONT - 2 ) begin
					l_vid <= dsi_pre_rgb_0;
					r_vid <= dsi_pre_rgb_0;
				end else if ( xpos == VID_HFRONT - 1 ) begin
					l_vid <= dsi_pre_rgb_1;
					r_vid <= dsi_pre_rgb_1;		
				end else if ( hactive ) begin
					l_vid <= l_prgb;
					r_vid <= r_prgb;
				end else if( xpos == VID_HBACK + VID_ACTIVE ) begin
					l_vid[15:0] <= l_crc;
					l_vid[63:16] <= dsi_post_rgb[63:16];
					r_vid[15:0] <= r_crc;
					r_vid[63:16] <= dsi_post_rgb[63:16];
				end else begin
					l_vid <= dsi_bp;
					r_vid <= dsi_bp;
				end
			end else begin
					l_vid <= dsi_bp;
					r_vid <= dsi_bp;
			end
		end else begin
			l_vid <= dsi_null;
			r_vid <= dsi_null;
		end
	end
	
	// data out to mipi dsi tx blocks
	reg vid_en_d;
	always @(posedge clk) vid_en_d <= vid_en;
	assign l_data = ( vid_en_d ) ? l_vid : ( ini_active ) ? l_cmd : 0;
	assign r_data = ( vid_en_d ) ? r_vid : ( ini_active ) ? r_cmd : 0;
`ifdef SIM
endmodule
`endif
	
    ////////////////////
	// MIPI Functions
    ////////////////////

	// MIPI DSI ECC funciton (9.3)
	// outputs 32 bits, input
	function [31:0] ecc; 
		input [23:0] din;
		reg [23:0] D;
		begin
			ecc[31:8] = din[23:0];
			// Need to account for section 9.3 bit ordering
			D[23:0] = { din[7:0], din[15:8], din[23:16] }; // switch to little endian for calc
			ecc[0] = D[0]^D[1]^D[2]^D[4]^D[5]^D[7]^D[10]^D[11]^D[13]^D[16]^D[20]^D[21]^D[22]^D[23];
			ecc[1] = D[0]^D[1]^D[3]^D[4]^D[6]^D[8]^D[10]^D[12]^D[14]^D[17]^D[20]^D[21]^D[22]^D[23];
			ecc[2] = D[0]^D[2]^D[3]^D[5]^D[6]^D[9]^D[11]^D[12]^D[15]^D[18]^D[20]^D[21]^D[22];
			ecc[3] = D[1]^D[2]^D[3]^D[7]^D[8]^D[9]^D[13]^D[14]^D[15]^D[19]^D[20]^D[21]^D[23];
			ecc[4] = D[4]^D[5]^D[6]^D[7]^D[8]^D[9]^D[16]^D[17]^D[18]^D[19]^D[20]^D[22]^D[23];
			ecc[5] = D[10]^D[11]^D[12]^D[13]^D[14]^D[15]^D[16]^D[17]^D[18]^D[19]^D[21]^D[22]^D[23];
			ecc[6] = 1'b0;
			ecc[7] = 1'b0;
		end
	endfunction	
	// Mipi endian swap
	function [63:0] swap8;
			input [63:0] din;
			integer ii;
			begin
				for( ii = 0; ii < 8; ii = ii + 1 ) begin
					swap8[ii*8+7-:8] = din[63-ii*8-:8];
				end
			end
	endfunction
	// MIPI DSI CRC function for long packet payloads
	function [3*8-1:0] crc1; input [1*8-1:0] d; begin crc1 = { d, crc( 5'd1, d ) }; end endfunction
	function [4*8-1:0] crc2; input [2*8-1:0] d; begin crc2 = { d, crc( 5'd2, d ) }; end endfunction
	function [5*8-1:0] crc3; input [3*8-1:0] d; begin crc3 = { d, crc( 5'd3, d ) }; end endfunction
	function [6*8-1:0] crc4; input [4*8-1:0] d; begin crc4 = { d, crc( 5'd4, d ) }; end endfunction
	function [7*8-1:0] crc5; input [5*8-1:0] d; begin crc5 = { d, crc( 5'd5, d ) }; end endfunction
	function [8*8-1:0] crc6; input [6*8-1:0] d; begin crc6 = { d, crc( 5'd6, d ) }; end endfunction
	function [9*8-1:0] crc7; input [7*8-1:0] d; begin crc7 = { d, crc( 5'd7, d ) }; end endfunction
	function [10*8-1:0] crc8; input [8*8-1:0] d; begin crc8 = { d, crc( 5'd8, d ) }; end endfunction
	function [11*8-1:0] crc9; input [9*8-1:0] d; begin crc9 = { d, crc( 5'd9, d ) }; end endfunction
	function [12*8-1:0] crc10; input [10*8-1:0] d; begin crc10 = { d, crc( 5'd10, d ) }; end endfunction
	function [19*8-1:0] crc17; input [17*8-1:0] d; begin crc17 = { d, crc( 5'd17, d ) }; end endfunction

	function [15:0] crc_round;
		input d;
		input [15:0] cin;
		begin
			crc_round = { 	cin[0] ^ d, 
			                cin[15:12],
							cin[11] ^ cin[0] ^ d,
							cin[10:5],
							cin[4] ^ cin[0] ^ d,
							cin[3:1] };
		end
	endfunction
	
	function [15:0] crc;
		input [4:0] len; // will be 1 to 17
		input [17*8-1:0] din;
		reg [15:0] sreg;
		integer ii, jj;
		begin
			sreg = 16'hffff;
			for( ii = 16; ii >= 0; ii = ii - 1 ) begin // traverse byte in transmit order
				if( ii < len ) begin // if inside data
					for( jj = 0; jj < 8; jj = jj + 1 ) begin // little endian bit order
						sreg[15:0] = crc_round( din[ii*8+jj], sreg );
					end
				end
			end
			crc = { sreg[7:0], sreg[15:8] }; // output is big endian 
		end
	endfunction

`ifndef SIM
endmodule
`endif


// Generate a video CRC
module vid_crc (
	reset, en, clk, data, crc
	);
	input wire reset;
	input wire en;
	input wire clk;
	input wire [63:0] data;
	output reg [15:0] crc;
	
	reg [15:0] sreg [0:64];
	integer ii;
	always @(crc, data) begin
		sreg[0] = crc;
		for( ii = 1; ii < 65; ii = ii + 1 ) begin
			sreg[ii] = crc_round( data[ii-1], sreg[ii-1] );
		end
	end
	
	always @(posedge clk) begin
		if( reset || !en ) begin
			crc <= 16'hffff;
		end else begin
			//crc <= sreg[64];
			// Optimized 64 bit checksum calc (synth should easily do this!?)
 			crc[0] <= ^({data[63:0],crc[15:0]} & 80'h11303471a041b343b343);
 			crc[1] <= ^({data[63:0],crc[15:0]} & 80'h226068e3408366876687);
 			crc[2] <= ^({data[63:0],crc[15:0]} & 80'h44c0d1c68106cd0fcd0f);
 			crc[3] <= ^({data[63:0],crc[15:0]} & 80'h8981a38d020d9a1f9a1f);
 			crc[4] <= ^({data[63:0],crc[15:0]} & 80'h233736ba45a877d877d);
 			crc[5] <= ^({data[63:0],crc[15:0]} & 80'h466e6d748b50efb0efb);
 			crc[6] <= ^({data[63:0],crc[15:0]} & 80'h8cdcdae916a1df61df6);
 			crc[7] <= ^({data[63:0],crc[15:0]} & 80'h119b9b5d22d43bed3bed);
 			crc[8] <= ^({data[63:0],crc[15:0]} & 80'h233736ba45a877db77db);
 			crc[9] <= ^({data[63:0],crc[15:0]} & 80'h466e6d748b50efb6efb6);
 			crc[10] <= ^({data[63:0],crc[15:0]} & 80'h8cdcdae916a1df6cdf6c);
 			crc[11] <= ^({data[63:0],crc[15:0]} & 80'h88981a38d020d9a0d9a);
 			crc[12] <= ^({data[63:0],crc[15:0]} & 80'h111303471a041b341b34);
 			crc[13] <= ^({data[63:0],crc[15:0]} & 80'h2226068e340836683668);
 			crc[14] <= ^({data[63:0],crc[15:0]} & 80'h444c0d1c68106cd06cd0);
 			crc[15] <= ^({data[63:0],crc[15:0]} & 80'h88981a38d020d9a1d9a1);
		end
	end
`ifndef SIM
// un-neccary replication due to verilog's lack of global functions
	function [15:0] crc_round;
		input d;
		input [15:0] cin;
		begin
			crc_round = { 	cin[0] ^ d, 
			                cin[15:12],
							cin[11] ^ cin[0] ^ d,
							cin[10:5],
							cin[4] ^ cin[0] ^ d,
							cin[3:1] };
		end
	endfunction
`endif
endmodule

// Generate an ECC
`ifdef SIM
module dsi_ecc(
	clk, reset, in, out
	);
	input reset, clk;
	input [23:0] in; // bin endian
	output [31:0] out; // data cat ecc big endian
	reg [31:0] ecc_reg;
	always @(posedge clk) begin
		if( reset ) begin
			ecc_reg <= 0 ;
		end else begin
			ecc_reg <= ecc( in );
		end
	end
	assign out = ecc_reg;
endmodule
`endif

// A test pattern generator
// 1600x1600 RGB, with L/R outputs (800wide),
// and 4 pixels/cycle, each 2 of 3 cycles 
module test_pattern_lcd (
		// system
		clk,
		reset,
		// Video sync input
		vsync,
		hsync,
		active, // 3 cycles earliy
		phase,
		// RGB Outputs
		rgb_left,
		rgb_right
	);
	// Video format parameters, derived from LCD datasheet
	// only those needed for video
	parameter VID_HEIGHT 	= 1600;
	parameter VID_WIDTH		= 1600;
	parameter VID_ACTIVE 	= 300; 

	// Declare I/O
	input wire clk;
	input wire reset;
	input wire vsync, hsync, active;
	input wire [2:0] phase; 
	output wire [4*3*8-1:0] rgb_left, rgb_right; 
	
	// Calculate current coordinate
	reg [10:0] x, y, px, py;
	reg del_active, act;
	always @(posedge clk) begin
		del_active <= active;
		act <= del_active; 
		py <= ( vsync ) ? 0 : ( del_active && !active ) ? py + 1 : py; // inc at end of each active row
		px <= ( hsync ) ? 0 : ( del_active &&  active && |phase[1:0] ) ? px + 4 : px; // inc during active phase 0 and 1, 4 pels per cycle
		x <= px;
		y <= py;
	end

	// calculate 8 RGB output pixels values per cycle 
    // adds 1 cycle delay
	// left lane offset 0,1,2,3
	wire [8:0] xl;
	assign xl = x[10:2];
	smpte_test i_left0( clk, act, {xl,2'd0}, y, rgb_left[ 7: 0], rgb_left[15: 8], rgb_left[23:16] );
	smpte_test i_left1( clk, act, {xl,2'd1}, y, rgb_left[31:24], rgb_left[39:32], rgb_left[47:40] );
	smpte_test i_left2( clk, act, {xl,2'd2}, y, rgb_left[55:48], rgb_left[63:56], rgb_left[71:64] );
	smpte_test i_left3( clk, act, {xl,2'd3}, y, rgb_left[79:72], rgb_left[87:80], rgb_left[95:88] );	
	// right lane offset 800, 801, 802, 803
	wire [8:0] xr;
    wire [1:0] dum;
	assign {xr, dum} = x + (VID_WIDTH/2);
	smpte_test i_right0( clk, act, {xr,2'd0}, y, rgb_right[ 7: 0], rgb_right[15: 8], rgb_right[23:16] );
	smpte_test i_right1( clk, act, {xr,2'd1}, y, rgb_right[31:24], rgb_right[39:32], rgb_right[47:40] );
	smpte_test i_right2( clk, act, {xr,2'd2}, y, rgb_right[55:48], rgb_right[63:56], rgb_right[71:64] );
	smpte_test i_right3( clk, act, {xr,2'd3}, y, rgb_right[79:72], rgb_right[87:80], rgb_right[95:88] );
	
endmodule

// Create a simple test pattern
module smpte_test(	clk, act, x,	y,	r,	g, b );
	// Image size params
	parameter VID_HEIGHT 	= 1600;
	parameter VID_WIDTH		= 1600;
	
	// declare I/O
	input wire clk;
	input wire [10:0] x, y;
	output wire [7:0] r, g, b;
	input wire act;
		// Test pattern colors 	
	localparam SMPTE_Argent 		= 24'hc0c0c0;
	localparam SMPTE_Acid_Green 	= 24'hc0c000;
	localparam SMPTE_Turquise_Surf 	= 24'h00c0c0;
	localparam SMPTE_Islamic_Green 	= 24'h00c000;
	localparam SMPTE_Deep_Magenta 	= 24'hc000c0;
	localparam SMPTE_UE_Red 		= 24'hc00000;
	localparam SMPTE_Medium_Blue 	= 24'h0000c0;
	localparam SMPTE_Oxford_Blue 	= 24'h00214c;
	localparam SMPTE_White 			= 24'hffffff;
	localparam SMPTE_Deep_Violet 	= 24'h32006a;
	localparam SMPTE_Eerie_Black 	= 24'h1d1d1d;
	localparam SMPTE_Chineese_Black = 24'h131313;
	localparam SMPTE_Vampire_Black 	= 24'h090909;
	
	// Derive rgb from x,y
	reg [23:0] rgb;

	always @(posedge clk) begin
		if( !act ) begin
			rgb <= 0;
		end else if( x == 0 || y == 0 || x == VID_HEIGHT-1 || y == VID_WIDTH-1 ) begin // Boarder square
			rgb <= SMPTE_White;
		end else if ( (x == 200 || x == 599 ) && y >= 200 && y < 600 ||
		              (y == 200 || y == 599 ) && x >= 200 && x < 600 ) begin // centered half size square
			rgb <= SMPTE_White;
		end else if ( x == y || x == VID_HEIGHT-y-1 ) begin // diagonal X
			rgb <= SMPTE_White;
		end else if ( y <= ((VID_HEIGHT*3)/4)) begin // Upper 7 color bars
			if( x < ((VID_WIDTH*1)/7)) begin
				rgb <= SMPTE_Argent;
			end else if( x < ((VID_WIDTH*2)/7)) begin
				rgb <= SMPTE_Acid_Green;
			end else if( x < ((VID_WIDTH*3)/7)) begin
				rgb <= SMPTE_Turquise_Surf;
			end else if( x < ((VID_WIDTH*4)/7)) begin
				rgb <= SMPTE_Islamic_Green;
			end else if( x < ((VID_WIDTH*5)/7)) begin
				rgb <= SMPTE_Deep_Magenta;
			end else if( x < ((VID_WIDTH*6)/7)) begin
				rgb <= SMPTE_UE_Red;
			end else begin
				rgb <= SMPTE_Medium_Blue;
			end
		end else begin // Lower 6 color bars
			if( x < ((VID_WIDTH*1)/6) ) begin
				rgb <= SMPTE_Oxford_Blue;
			end else if( x < ((VID_WIDTH*2)/6) ) begin
				rgb <= SMPTE_White;
			end else if( x < ((VID_WIDTH*3)/6) ) begin
				rgb <= SMPTE_Deep_Violet;
			end else if( x < ((VID_WIDTH*4)/6) ) begin
				rgb <= SMPTE_Eerie_Black;
			end else if( x < ((VID_WIDTH*5)/6) ) begin
				rgb <= SMPTE_Chineese_Black;
			end else begin
				rgb <= SMPTE_Vampire_Black;
			end
		end
	end
	// Output
	assign {r,g,b} = rgb;
endmodule

module hex_font4 (
		// system
		clk,
		reset,
		// Video sync input
		vsync,
		hsync,
		active, // 3 cycle earliy
		phase,
		// Char location
		char_x, 
		char_y,
		hex_char  // easy to use for hex display, 1 cycle early
	);

	// Declare I/O
	input wire clk;
	input wire reset;
	input wire vsync, hsync, active;
	input wire [2:0] phase;
	output wire [7:0] char_x;
	output wire [7:0] char_y;
	output wire [63:0] hex_char;  // easy to use for hex display
	
	// Calculate current coordinate
	reg [10:0] x, y;
	reg del_active;
	always @(posedge clk) begin
		del_active <= active;
		// add 1 cycle
		y <= ( vsync ) ? 11'd0 : ( del_active && !active ) ? y + 11'd1 : y;
		x <= ( hsync ) ? 11'd0 : ( active && |phase[1:0] ) ? x + 11'd1 : x;
	end

	assign char_x = x[10:3]; 
	assign char_y = { 1'b0, y[10:4]};
	
	// Simple 5x7 hex char font, 8 rows, expaded to 7x14, on a 8x16 grid
	reg [16*5-1:0] hex_char_row;
	always @(y) begin
		case ( y[3:1] ) 
		3'd0: hex_char_row = 80'b01110_00100_01110_11110_10001_11111_01110_11111_01110_01110_01110_11110_01110_11110_11111_11111;
		3'd1: hex_char_row = 80'b10001_01100_10001_00001_10001_10000_10001_00001_10001_10001_10001_10001_10001_10001_10000_10000;
		3'd2: hex_char_row = 80'b10011_00100_00001_00001_10001_10000_10000_00001_10001_10001_10001_10001_10000_10001_10000_10000;
		3'd3: hex_char_row = 80'b10101_00100_00010_01110_11111_11110_11110_00010_01110_01111_10001_11110_10000_10001_11110_11110;
		3'd4: hex_char_row = 80'b11001_00100_00100_00001_00001_00001_10001_00100_10001_00001_11111_10001_10000_10001_10000_10000;
		3'd5: hex_char_row = 80'b10001_00100_01000_00001_00001_00001_10001_00100_10001_10001_10001_10001_10001_10001_10000_10000;
		3'd6: hex_char_row = 80'b01110_01110_11111_11110_00001_11110_01110_00100_01110_01110_10001_11110_01110_11110_11111_10000;
		default: hex_char_row = 80'b0;
		endcase
	end
		
	// expand out the data to 8 char width, depandand upon x[0], 
	reg [16*4-1:0] exp_row;
	integer ii;
	always @(x, hex_char_row) begin
		for( ii = 0; ii < 16; ii = ii + 1 ) begin
			exp_row[ii*4+3-:4] = (x[0]) ? { hex_char_row[80-ii*5-4], hex_char_row[80-ii*5-5], hex_char_row[80-ii*5-5], 1'b0 } 
			                             : { hex_char_row[80-ii*5-1], hex_char_row[80-ii*5-1], hex_char_row[80-ii*5-2], hex_char_row[80-ii*5-3] };
		end
	end

	reg [63:0] hex_reg;
	always @(posedge clk)
		hex_reg <= exp_row;
	assign hex_char = hex_reg;
endmodule

module hex_overlay4
#( 
	parameter LEN = 1 
)
(
	// System
	clk,
	reset,
	// Font generator input
	char_x,
	char_y,
	hex_char, // supported chars else zero
	// Display string and X,Y start 
	in, // input number
	x,
	y,
	// The video output is 4 bits, each gating a 32b RGB value
	out
);	

	// define I/O
	input wire clk, reset;
	input wire [7:0] char_x, char_y;
	input wire [63:0] hex_char; // supported chars else zero
	input wire [LEN*4-1:0] in; // input number
	input wire [7:0] x;
	input wire [7:0] y;
	output wire [3:0] out;

	reg [LEN-1:0] cov0, cov1, cov2, cov3;
	integer ii;
	always @(char_x, char_y, hex_char, in, x, y) begin
		// Loop through chars, index the ascii data, gate with location and pack for OE
		for( ii = 0; ii < LEN; ii = ii + 1 ) begin
			{ cov3[ii], cov2[ii], 
			  cov1[ii], cov0[ii] }  = ( char_x != ( x + ii ) ) ? 4'b0000 :
			                           ( char_y !=   y        ) ? 4'b0000 :
									   ( in[(LEN-ii)*4-1-:4] == 4'h0 ) ? hex_char[0*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h1 ) ? hex_char[1*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h2 ) ? hex_char[2*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h3 ) ? hex_char[3*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h4 ) ? hex_char[4*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h5 ) ? hex_char[5*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h6 ) ? hex_char[6*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h7 ) ? hex_char[7*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h8 ) ? hex_char[8*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'h9 ) ? hex_char[9*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'hA ) ? hex_char[10*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'hB ) ? hex_char[11*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'hC ) ? hex_char[12*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'hD ) ? hex_char[13*4+3-:4] :
									   ( in[(LEN-ii)*4-1-:4] == 4'hE ) ? hex_char[14*4+3-:4] :
									   /* in[(LEN-ii)*4-1-:4] == 4'hF )*/ hex_char[15*4+3-:4] ;
		end
	end
	reg [3:0] oreg;
	always @(posedge clk)
		oreg <= { |cov3, |cov2, |cov1, |cov0 }; // reduction OR :)
	assign out = oreg;
	
endmodule

module commit_overlay
// R is 29 to give a 16 second total period with 62.5 Mhz clk
// can be shortened for SIM puposed
#( 
	parameter R =  29
)
( 
		// system
		clk,
		reset,
		// Video sync input
		vsync,
		hsync,
		active,
		phase,
		// output
		out,
		blink
	);
	
	
	// Declare I/O
	input wire clk;
	input wire reset;
	input wire vsync, hsync, active;
	input wire [2:0] phase;
	output wire [3:0] out;
	output wire blink;

	// Video location
	// Calculate current coordinate
	// active is 3 cycles early
	reg [10:0] x, y;
	reg del_active;
	always @(posedge clk) begin
		del_active <= active;
		// x and y add 1 cycle
		y <= ( vsync ) ? 0 : ( del_active && !active ) ? y + 1 : y; // 1 Step is 1 line
		x <= ( hsync ) ? 0 : ( active && |phase[1:0] ) ? x + 1 : x; // 1 step is 4 pels
	end 
	
	// Commit Rom 
	reg [7:0] commit_rom [63:0]; /* synthesis syn_ramstyle= "block_ram" */
	initial $readmemb("commit.mem", commit_rom );

	// Window for id, hard coded location
	// y[10:4] == 7'd80 gives us pel row 80*16 , 
    // x[10:4] == 7'd1 gives us pel cols 16*4 through 32*4 
	wire window;
	assign window = ( y[10:4] == 7'd80 && x[10:4] == 7'd1 ) ? 1'b1 : 1'b0;
	
	reg [29:0] bcnt; // 16 sec counter
	always @(posedge clk)
		bcnt = bcnt + 1;
	
	wire [5:0] raddr;
	reg [7:0] rdata;
	assign raddr[5:0] = ( window ) ? { x[3:1], y[3:1] } : // double the height, 2 nibble per row
						              { bcnt[R-:3], 3'b111 }; // row 7 is binary for the char
	always @(posedge clk) rdata <= commit_rom[ raddr ]; // read ROM
	
	reg del_x0;
	reg del_window;
	reg [3:0] oreg;
	always @(posedge clk) begin
		// delay to match rom, it added 2nd cycle
		del_window <= window;
		del_x0 <= x[0];
		//  output is the 3rd cycle
		oreg <= ( !del_window ) ? 4'b0000 : // outside window
				 ( y[3:1] == 3'b111 ) ? 4'b0000 : // bottom row contains blink data
	             ( del_x0 ) ? { rdata[1], {2{rdata[0]}}, 1'b0 } :
	                          { {2{rdata[4]}}, rdata[3:2] };
	end
	assign out = oreg;
  
	// Blink Output
	// will blink out Commit id 0: (*-*-----) and 1: (***-----) for 28 bits, 2 bits per sec, then a 2 second blank
	assign blink = ( bcnt[R-:3] == 3'd7 ) ? 1'b0 : // blank for last digit (4 bits) 2 sec.
	               ( bcnt[R-5-:3] == 3'd0 ) ? 1'b1 :
	               ( bcnt[R-5-:3] == 3'd2 ) ? 1'b1 :
	               ( bcnt[R-5-:3] == 3'd3 ) ? 1'b0 :
	               ( bcnt[R-5-:3] == 3'd4 ) ? 1'b0 :
	               ( bcnt[R-5-:3] == 3'd5 ) ? 1'b0 :
	               ( bcnt[R-5-:3] == 3'd6 ) ? 1'b0 :
	               ( bcnt[R-5-:3] == 3'd7 ) ? 1'b0 :
				   ( bcnt[R-3-:2] == 2'd0 ) ? rdata[3] : // MSB first
				   ( bcnt[R-3-:2] == 2'd1 ) ? rdata[2] :
				   ( bcnt[R-3-:2] == 2'd2 ) ? rdata[1] :
				   /*bcnt[R-3-:2]  == 2'd3 )*/ rdata[0] ;
endmodule
