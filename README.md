## CrossLink_LCD
Verilog fpga design directly using a Lattice CrossLink's hard MIPI D-PHY cores' for an 8gbps 2x4lane Mipip Dsi controlled LCD 
This repo contains the
[public_surface](https://github.com/ericpearson1313/CrossLink_LCD#crosslink_lcd)
of a custom design targetting a special purpose LCD display.

### Lattice Crosslink FPGAs 
The Lattice crosslink fpga's are targetted at video bridging of mobile image sensors and displays. 
Lattice's Diamond design software provides free tools for verilog synthesis, place and route.
Showcasing two(2) hardened 4-lane MIPI D-PHY interfaces plus 37 high speed I/O pin , and 5936x Lut4s and 20x 9kbit block rams , alot of logic can be packed in the LIF-MD6000. Alot of  functionallity at a sub-$5 cost.

# Design
This design is an interface to a custom LCD module use a 2x4Lane interface that supports 1800x1800 at 100Hz of RGB24 without compression.
It is a custom scratch flat verilog design. It directly instantiating the FPGA's MIPI D-PHYs and emits an RGB image of a Smpte style color-bar test pattern.
The design includes video sync generation, RGB888 test pattern generation with text overlay, MIPI DSI LCD intialization and video stream generation, and integration on a dev board.   

![floorplan](Screenshot%202026-01-31%20143339.png "Crossfire floorplan")

The floorplan shows the crossfire device with a design snapshot with 55% utillzation. The two MIPI D-PHYs are the blocks at the top, and the 16 block rams are shown across the middle
The array of FPGA LAB each contain 4 Luts with flipflops. 



## Display pipeline

The design configures the MIPI blocks as 16:1, so in HS mode 64bits are sent to each mipi block, each cycle, at 62.5Mhz. For RGB888 this gives 8 pixels every 3 cycles. For convenience RGB data is formatted as 4 pels of RRGB88 per cycle per lane every 2 of 3 cycles (2:3 phase style clock crossing). A simple RGB frame generator takes in video sync singels and generates the X, Y addresses and logic to generate a RGB test pattern. The RGB test pattern generator is instantiated 8 times to generate 4 pels at differnt X locations for each of the 2 lanes.

### Video sync
Outputs of the mipi_format_lcd() module include the video sync signals used to format the RGB input data. Included are the hsync and vsycn strobes, an *early* active signal and a phase[2:0] signal used to covert the rates and pack the 24 bit RGB into mipi lanes.

### Test Pattern Generation

smpte_test() takes in the x,y pel location and generates a 24 bit RGB output. The logic I use generates my approximation of the SMPTE color bars, with the addition of outer boundary and inner square with a corner to corner diagonal in white.

test_pattern_lcd() uses the video sync inputs to derive x,y values. Eight(8) pixels per cycle are needed to feed the 2x4 mipi lanes using a 2:3 mapping. To do this the smpte_test() is instantiated 8 times, each with an X offset from the current location.

note: The RGB data is packed in little endian order on the MIPI interface so is actually represented as { G, B, R }.

### RGB to MIPI mapping

The RGB data is active during phase 0 and phase 1 clock cycles (and is ignored during phase 2).
A single register holds the last valid data, and a mux is able to generate 3 mipi words with 0 latency.

This mapping logic is contained in mipi_format_lcd() and is done for both right and left 1x4 lanes

    // Register RGB inputs
    // 2:3 rgb:mipi conversion logic
    reg [96:0] mreg, sreg;
    always @(posedge clk) begin
        mreg <= m_rgb;
        sreg <= s_rgb;
    end
	
    // Pack RGB inputs into mipi words
    // first word of RGB data arrives aligned with h_active, whith data on ph0, ph1
    wire [63:0] m_prgb, s_prgb;
    assign m_prgb[63:0] = ( ph[0] ) ? m_rgb[63:0] : ( ph[1] ) ? { m_rgb[31:0], mreg[95:64] } : mreg[95:32];
    assign s_prgb[63:0] = ( ph[0] ) ? s_rgb[63:0] : ( ph[1] ) ? { s_rgb[31:0], sreg[95:64] } : sreg[95:32];

### DSI Video Formatting
Along with the packed RGB data DSI video formatting needs to be generated. Hardware counters are used to generate VIDEO formatted as needed by the LCD display. The counters are used to determine when to send commands from a set of pre-assembled DSI packets. Compile time functions for eroor correction, message crc calc, and endian swap are used. This keeps the messages readable, and uses no device logic. The messages are organized into 64 bit words. These will be packed into FPGA Lut logic. 

	assign dsi_bp 			= swap8( { ecc( { 8'h19, 8'h02, 8'h00 } ), crc2( { 8'h00, 8'h00 } ) } );
	assign dsi_null 		= swap8( { ecc( { 8'h09, 8'h02, 8'h00 } ), crc2( { 8'h00, 8'h00 } ) } );
	assign dsi_vss          = swap8( { ecc( { 8'h01, 8'h00, 8'h00 } ), ecc( { 8'h19, 8'h06, 8'h00 } ) } );
	assign dsi_hss          = swap8( { ecc( { 8'h21, 8'h00, 8'h00 } ), ecc( { 8'h19, 8'h06, 8'h00 } ) } );
	assign dsi_post_short	= swap8( crc6( {6{8'h00}} ) );
	assign dsi_pre_rgb      = { ecc( { 8'h19, 8'h06, 8'h00} ), crc6( {6{8'h00}} ), ecc( { 8'h3E, 8'h84, 8'h03} ) }; 
	assign dsi_pre_rgb_0	= swap8( dsi_pre_rgb[127:64] );
	assign dsi_pre_rgb_1	= swap8( dsi_pre_rgb[63:0] );
	assign dsi_post_rgb		= swap8( { 16'h0000, ecc( { 8'h19, 8'h00, 8'h00 } ), 16'hffff } );
	assign dsi_disp_on		= swap8( { ecc( { 8'h05, 8'h29, 8'h00 } ), ecc( { 8'h05, 8'h11, 8'h00 } ) } );

The vsync and hsync events are sent as 2 words each, the first containing the given 4 byte short message ( 8'h01 or 8'h21 respectively ) and the start of a 12 byte blanking packed (8'h19). The 2nd word is common port_short for all short messages. All otherwise unused cycles are filled with 8 byte aligned blanking packets.

Of note are the words before and after the RGB data, to align it with the received and unpacked RGB input data. The post rgb message contains the CRC for the video row transmitted throught the given lane. If it crc is ignored by the given display the 16'h0000 is sufficient. Otherwise the CRC needs to be calculated on the full video data and be available with the last pel on the line. 

### Video row CRC calculation
My first at this takes a significant 15% of the device for the dual CRC units. They are capable of sustained 8 Gbit CRC calculation so may be deserved. I have not yet looked into optimizing this logic, especially before we see if the display can ignore it (save 15%!).

I would have prefered system verilog multi-dimensional arrays to code this loop, but verilog can suffice. 
The loop applies the algorithm for the 64 input bits each cycle.
The crc is initialized to FFFF at the start of each RGB pixel row (for the given half of the display).

	reg [15:0] sreg [0:64];
	integer ii;
	always @(crc, data) begin
		sreg[0] = crc;
		for( ii = 1; ii < 65; ii = ii + 1 ) begin
			sreg[ii] = { data[ii-1] ^ sreg[ii-1][0],
			              sreg[ii-1][15:12],
						  data[ii-1] ^ sreg[ii-1][0] ^ sreg[ii-1][11],
						  sreg[ii-1][10:5],
						  data[ii-1] ^ sreg[ii-1][0] ^ sreg[ii-1][4],
						  sreg[ii-1][3:1] };
		end
	end

Well the CRC calc is blocking timing closure, so I tried some hand optimization. I should not be able to optimize combinatorial logic better than the synthesis tools, but worth a try. To do this I used system verilog to write dense verilog code. This SV code (in testbench.sv) does the CRC cacluations but carries around 80 bits for every crc bit of 64 stages. The Xor logic of the CRC cacl is performed on the full 80 bit vector, this way the output is dependant upon the input CRC[15:0] and Data[63:0] that are xor'ed in an odd number of time.

		/////////////////////////////////////////
		// Build the Constant CRC matrix
		//logic [64:0][15:0][79:0] S;
		//logic [63:0][79:0] D
		// Init D
		D = 0;
		for( int ii = 0; ii < 64; ii++ )
			D[ii][ii+16] = 1'b1;
		// Init S[0];
		S = 0;
		for( int ii = 0; ii < 16; ii++ )
			S[0][ii][ii] = 1'b1;
		// Round Calcs
		for( int ii = 1; ii <= 64; ii++ ) 
			for( int jj = 0; jj < 16; jj++ ) 
				S[ii][jj] = ( jj == 15 ) ? ( D[ii-1] ^ S[ii-1][0] ):
					    ( jj == 10 ) ? ( D[ii-1] ^ S[ii-1][0] ^ S[ii-1][11] ):
					    ( jj == 3  ) ? ( D[ii-1] ^ S[ii-1][0] ^ S[ii-1][4] ):
						           S[ii-1][jj+1];
		// dump dense logic
		for( int ii = 0; ii < 16; ii++ ) 
			$display(" crc[%1d] <= ^({data[63:0],crc[15:0]} & 80'h%0h);", ii, S[64][ii] );
		/////////////////////////////////////////

The verilog code produced uses a reduction xor of the 80 input bits {data[63:0],crc[15]} ANDed with a unique 80bit mask for each output bit. Hopefully the
synthesis tool will take advantage of this.

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

The lattice diamond synthesis tool, using this optimized logic produced logic that was 2x faster and 1/3 the area. I think the tool should have achieved these results on its own without me re-coding it. It does show there is *alot* of area and performance avaialable by moving to better synth tools than the basic diamond ones.

### Mipi Dsi LP11 to HS transition
The plan is to run the interface in HS mode using BP packets during video blanking.
During power up and reset the Mipi clock and data lanes are in LP11 stop state.
The hardware transitions the MIPI interface from LP11 (lower power stop state) to the HS (high speed) a suitable period after reset is done.

This operation is a sequence to first transition the clk from LP to HS, and then all the data lanes form LP to HS. The transitionin follows a standard sequnce for each: {lp11,lp01,lp00,hs0}
the signal transitions and timing were aligned with the 16ns clock (62.5Mhz) and are described as digital waveforms spanning 40 cycles.

	// first entry is reset state, final entry is running state
	// Clk lane startup
	//                    lp11,lp01,lp00,  clk hs00     ,clk start
	wire [0:39] clpen = 40'b1_1111_1111_000000000000000_0_0000_0000_000000_0;
	wire [0:39] clpdp = 40'b1_0000_0000_000000000000000_0_0000_0000_000000_0;
	wire [0:39] clpdn = 40'b1_1111_0000_000000000000000_0_0000_0000_000000_0;
	wire [0:39] chsen = 40'b0_0000_0000_111111111111111_1_1111_1111_111111_1;
	wire [0:39] chsgt = 40'b0_0000_0000_000000000000000_1_1111_1111_111111_1; // polarity?
	// Data Lane startup                         data lp11,lp01,lp00,hs0   ,hs start
	wire [0:39] dlpen = 40'b1_1111_1111_111111111111111_1_1111_1111_000000_0;
	wire [0:39] dlpdp = 40'b1_1111_1111_111111111111111_1_0000_0000_000000_0;
	wire [0:39] dlpdn = 40'b1_1111_1111_111111111111111_1_1111_0000_000000_0;
	wire [0:39] dhsen = 40'b0_0000_0000_000000000000000_0_0000_0000_111111_1;

a transition counter (start_cnt) is reset to 0 and when enabled counts to 39 and then holds. Muxing the waves drives the D-PHY control signals;

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

# Debug Logic
This is the *optional* part of the design. It is practically necessary though, so I tend to put it first in development for any new platform.

The beauty of fpga's is that they can be quickly modified. Sometimes it is quicker to try the fpga on the actual device verses RTL simulation as we do for chips. Adding some debug tools helps alot with this. Hardware debug often involves observing LEDs. For FPGA projects where the logic controls the display pixels you can treat the display pixels as LEDs and use them to directly display live FPGA state. 

If your design don't hve a display, a tiny bit of logic and 4 outputs can be used used to generate and HDMI output, but that is not needed hfor this design. I recommend to add an HDMI port to any new fpga board design. An HDMI wires directly connect to 4 differential outputs on the fpga. Its really handy if, years down the road, all you need is a hdmi cable to debug the live state of an fpga in the field. Nuff said.

## Hexadecimal overlay
A 'little bit' of logic tiles a full font of 5x7 characters over the image. By selectively ORing these signals into the video based on x, y and probed state, we can display live state directly with zero latency. This is used to dump hexadecimal values such as performance measurements, counters or state. I use this alot to quickly debug fpga logic. It may be useful in this case, so it was a tool I added at the beginning in this platform. Unlike a rom based font, this logic grows linearly with the number of characters displayed, and can get quite large, so as the chip fills up with intended logic, this is the first logic to be turned off. I use a single Verilog OR(|) statement to control which strings are overlayed as White on the video. This allows quickly turning off a line of text and the synthesis tool will prune the logic, allowed to keep the debug statements in place for future use if/when need.

Currently there are two 32 bit counters, displayed as 8 hex digits: 100Hz frame counter, and 62.5Mhz system clock.

## Hardware Debug, Commit ID
Embedding 7 digit hex git repo ID in the FPGA bitfile is a powerful debug tool.
 
### Watermarking
A watermark script is used to embed the git commit id7 into the fpga design.
The watermark.sh script is run after git clone/pull/checkout, before the fpga build. It runs with only git referenced tools (eg awk), so will run in where git runs. The script reads and formats the 7 hex digit commit id7 into a rom initiazation file (commit.mem). During the fpga build flow, this file is used as the initialization of small rom. This way the synthesis results do not change from the build that commmit was associated with (re-builds are not guaranteed identical if the source code is changes, but you can change a ROM's contents).

### Commit video overlay
I use a commit ROM on all my fpga video designs with the output overlayed as text on the video. The aids debug by directly connecting video effects on display with git commit version. A simple photo then becomes an powerful debug artefact.  For this design I actually render the 7 hex digits as a 5x7 font into the rom with the script. This is coded as a bitmap in the rom, and is used to overay white text onto the display at 4 bits per cycle. Using pel duplication the font is expanded 5x7 to 7x14 on display overlay (its tiny at these resolutions).

### Commit LED blink.
THe blinking LED is the first fpga run on a new board, often with a custom pattern. Since this project ivolves bringing up the display it is helpful to also *blink* the commmit id out over a 16 second period. A 2sec period with the LED off separates 28 periods each representing a bit of the id7, msb first. During the 1/2 bit interval, a zero (0) is represented by \*-\*----- and a one (1) is represented by a \*\*\*----- (where * indicated led is on for 1/16 sec, - is off).
The blink control bits are in the 8th row of the 5x7 fonts. I may swap the meaning of these bits, we'll so how it goes.

The default commit id7 for the repo's commit.mem = 28'hABC0123, which would be coded in binary as 1010_1011_1100_0000_0001_0010_0011.
The first 4 bit nibble after reset and repeated every 16 sec would be (\*\*\*-----\*-\*-----\*\*\*-----\*-\*-----).

### commit.mem format
For the crosslink we have 20 blockrams, 1 of which is used as a rom for this purpose, and external logic otherwise is minimized by bit mapping hexadecimal character data for both video and LED blink code ito the memory bits in commit.mem in a mnner providing each address generation and paralelle bits for output.

For example the character 'A':

    00001110
    00010001
    00010001
    00010001
    00011111
    00010001
    00010001
    00001010
    
Note the bottom row is the binary output used for blink, and ignored for display.

# Building the project

    git clone/pull/checkout
    sh ./watermark.sh # will modify commit.mem with git commit just pulled
    # In DIamond open testgen.ldf
    # build fpga programming file
    git checkout -- commit.mem #get back repo copy before next pull

    
    



