// Adhoc collection of verilator test benches created during project development
// customize the run_test to select which _tb to build and run

// test ECC
module ecc_tb();
	logic clk;
	logic reset;

	// Create clock
	initial begin
		clk = 0;
		for( ;; ) begin
			#(10ns);
			clk = !clk;
		end
	end

	// create reset
	initial begin
        $timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        // configure FST (waveform) dump
        $dumpfile("ecc.fst");
        $dumpvars(1,i_dut);
		reset = 1;
		for( int ii = 0; ii < 10; ii++ ) begin
			@(negedge clk);
		end
		reset = 0;
                $display("Reset done");
		for( int ii = 0; ii < 50000; ii++ ) begin
			@(negedge clk);
		end
                $display("done");
		$finish();
	end

	// DUT
	logic [23:0] din;
	logic [31:0] ecc_reg;
	dsi_ecc i_dut (
		.reset( reset ),
		.clk( clk ),
		.in( din ),
		.out( ecc_reg )
	);

	initial begin
		din = 0;
		while( reset ) @(negedge clk); // wait for reset to finish
		@(negedge clk);

		// Test case from 9.4A, as big endian!
		din={ 8'h37, 8'hf0, 8'h01 };
		$display("Din = %h", din);
		@(negedge clk);
		$display("ECC hw 0x%h, should be 0x3F, %s", ecc_reg, ( ecc_reg == { din, 8'h3f } ) ? "PASS":"FAIL" );

		// finish up
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
		$finish();
	end
endmodule
	
// Test and view the MIPI startup sequencing
module dsi_tb();
	logic clk;
	logic reset;
	
	// Create 62.5 Mhz clock
	initial begin
		clk = 0;
		for( ;; ) begin
			#(8ns);
			clk = !clk;
		end
	end

	// create 62.5 Mhz (shifted, right lane)
	logic rclk;
	initial begin
		rclk = 0;
		#(5ns)
		for(;;) begin
			#(8ns)
			rclk = !rclk;
		end
	end

	// create 66.66 Mhz
	logic pclk;
	initial begin
		pclk = 0;
		for(;;) begin
			#(8ns)
			pclk = !pclk;
			#(7ns)
			pclk = !pclk;
		end
	end

	// create reset
	initial begin
        $timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        // configure FST (waveform) dump
        $dumpfile("dsi.fst");
        $dumpvars(1,i_dut);
        $dumpvars(1,i_dut1);
        $dumpvars(1,i_dut2);
		reset = 1;
		for( int ii = 0; ii < 10; ii++ ) begin
			@(negedge clk);
		end
		reset = 0;
                $display("Reset done");
		for( int ii = 0; ii < 150*62500; ii++ ) begin // 100 ms
			@(negedge clk);
		end
                $display("Test terminated, exceeded MY time line");
		$finish();
	end

	// instantiate DUT

	// Left Lane
	logic lcd_reset, lcd_pn2ptx, lcd_en_vsp, lcd_en_vsn, lcd_en_vcc;
	logic l_txlpen, l_txlpn, l_txlpp, l_txhsen;
	wire l_ctxlpen, l_ctxlpn, l_ctxlpp, l_ctxhsen, l_ctxhsgate;
	logic [63:0] l_data, r_data;
	logic [95:0] l_rgb, r_rgb;
	logic l_vsync, l_hsync, l_active;
	logic [2:0] l_phase;
	logic [3:0] ovl;
	mipi_format_lcd i_dut(
		// System
		.clk	( clk ),
		.reset	( reset ),
		.lane   ( 1'b0 ),
		// LCD control outputs
		.lcd_reset( lcd_reset ),
		.lcd_pn2ptx( lcd_pn2ptx ),
		.lcd_en_vsp( lcd_en_vsp ),
		.lcd_en_vsn( lcd_en_vsn ),
		.lcd_en_vcc( lcd_en_vcc ),
		// Mipi Control Outputs
		.txlpen	( l_txlpen ),
		.txlpn	( l_txlpn ),
		.txlpp	( l_txlpp ),
		.txhsen	( l_txhsen ),
		.clk_txhsen	( l_ctxhsen ), 
		.clk_txhsgate	( l_ctxhsgate ), 
		.clk_txlpen	( l_ctxlpen ), 
    		.clk_txlpn 	( l_ctxlpn ), 
		.clk_txlpp	( l_ctxlpp ),
		// Mipi Tx Data
		.data ( l_data[63:0] ),
		// Video Sync output
		.vsync ( l_vsync ),
		.hsync ( l_hsync ),
		.active( l_active ),
		.phase ( l_phase[2:0] ),
		// RGB Inputs
		.rgb	( l_rgb[95:0] )
	);

	// Right Lane
	logic r_txlpen, r_txlpn, r_txlpp, r_txhsen;
	wire r_ctxlpen, r_ctxlpn, r_ctxlpp, r_ctxhsen, r_ctxhsgate;
	logic r_vsync, r_hsync, r_active;
	logic [2:0] r_phase;
	mipi_format_lcd i_dut1(
		// System
		.clk	( rclk ),
		.reset	( reset ),
		.lane   ( 1'b1 ),
		// LCD control outputs
		.lcd_reset( ),
		.lcd_pn2ptx( ),
		.lcd_en_vsp( ),
		.lcd_en_vsn( ),
		.lcd_en_vcc( ),
		// Mipi Control Outputs
		.txlpen	( r_txlpen ),
		.txlpn	( r_txlpn ),
		.txlpp	( r_txlpp ),
		.txhsen	( r_txhsen ),
		.clk_txhsen	( r_ctxhsen ), 
		.clk_txhsgate	( r_ctxhsgate ), 
		.clk_txlpen	( r_ctxlpen ), 
    		.clk_txlpn 	( r_ctxlpn ), 
		.clk_txlpp	( r_ctxlpp ),
		// Mipi Tx Data
		.data ( r_data[63:0] ),
		// Video Sync output
		.vsync ( r_vsync ),
		.hsync ( r_hsync ),
		.active( r_active ),
		.phase ( r_phase[2:0] ),
		// RGB Inputs
		.rgb	( r_rgb[95:0] )
	);

	wire p_active, p_hsync, p_vsync;
    	wire [95:0] p_rgb;
    	lcd_split i_dut2(
        	// System
        	.reset ( reset ),
        	// Left MIPI Lane
        	.l_clk ( clk ),
        	.l_rgb( l_rgb ),
        	.l_active( l_active ),
        	.l_phase( l_phase ),
        	.l_hsync( l_hsync ),
        	.l_vsync( l_vsync ),
        	// Left MIPI Lane
        	.r_clk ( rclk ),
        	.r_rgb( r_rgb ),
        	.r_active( r_active ),
        	.r_phase( r_phase ),
        	.r_hsync( r_hsync ),
        	.r_vsync( r_vsync ),
        	// Pixel Interface
        	.p_clk ( pclk ),
        	.p_rgb ( p_rgb | {{24{ovl[0]}},{24{ovl[1]}},{24{ovl[2]}},{24{ovl[3]}}} ),
        	.p_hsync( p_hsync ),
        	.p_vsync( p_vsync ),
        	.p_active( p_active )
    	);


    	test_pattern_lcd i_test_pat (
		// system
		.clk	( pclk ),
		.reset  ( reset ),
		// Video sync input
		.vsync	( p_vsync ),
		.hsync	( p_hsync ),
		.active ( p_active ),
		// RGB Outputs
		.rgb   ( p_rgb[95:0]  )
	);

	// Hex overlays
	wire [7:0] char_x, char_y;
	wire [63:0] hex_char;
	hex_font4 i_font (
		// system
		.clk	( pclk ),
		.reset  ( reset ),
		// Video sync input
		.vsync	( p_vsync ),
		.hsync	( p_hsync ),
		.active ( p_active ),
		// Char location and data
		.char_x ( char_x ),
		.char_y ( char_y ),
		.hex_char ( hex_char )
	);

	wire blink;
	wire [3:0] ovl0, ovl1, ovl2;
	// speed up blink so it finishes in sime time
	commit_overlay #(22) i_com_ovl( pclk, reset, p_vsync, p_hsync, p_active, ovl0, blink); 
	
	// Frame counter hex overlay
	reg [31:0] frame_count;
	always @(negedge pclk) begin
		frame_count <= ( reset ) ? 0 : ( p_vsync ) ? frame_count + 1 : frame_count;
	end
	hex_overlay4 #( 8 ) i_hex1( pclk, reset, char_x, char_y, hex_char, frame_count, 8'd90, 8'd4, ovl1 );
	
	// Clock counter hex overlay 
	reg [31:0] clk_count;
	always @(negedge pclk) 
		clk_count <= ( reset ) ? 0 : clk_count + 1;
	hex_overlay4 #( 8 ) i_hex2( pclk, reset, char_x, char_y, hex_char, clk_count, 8'd90, 8'd6, ovl2 );
	
	// Or together the overlays
	// Toggle debug overlay HERE, synthesis removed unsed logic
	//assign ovl = ovl0; // just commit overlay rom, small (+3%) try to always keep!
	assign ovl = ovl0 | ovl1 | ovl2; // add dynamic debug overlays, largish (cost=14%), can be useful

	// Log the DSI outputs to binary DSI byte files
	integer lfd, rfd;
    	initial begin // lgg left DSI
		lfd = $fopen("left.dsi", "wb");
		for(;;) begin
			@(negedge clk);
			if( l_ctxhsen ) begin
				for( int ii = 0; ii < 8; ii++ ) begin
					$fwrite(lfd, "%c", l_data[ii*8+7-:8] );
				end
			end
		end
	end

    	initial begin // log right DSI
		rfd = $fopen("right.dsi", "wb");
		for(;;) begin
			@(negedge rclk);
			if( r_ctxhsen ) begin
				for( int ii = 0; ii < 8; ii++ ) begin
					$fwrite(rfd, "%c", r_data[ii*8+7-:8] );
				end
			end
		end
	end

	// Run the test
    	initial begin
		while( reset ) @(negedge clk); // wait for reset to finish

		// wait 6ms of power up
		for( int ii = 0; ii < 26*62500; ii++ ) @(negedge clk);

		// wait for init sequence
		for( int ii = 0; ii < 32; ii++ ) @(negedge clk);

		// wait for 6 frames sequence
		for( int ii = 0; ii < 7*1779*390; ii++ ) @(negedge clk);

		// wait for BL control >40ns
		for( int ii = 0; ii < 3; ii++ ) @(negedge clk);

		// wait for 2 real frames
		for( int ii = 0; ii < 2*1779*390; ii++ ) @(negedge clk);
		
		// finish up sim 
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
                $display("Test completed normally");
		$fclose( lfd );
		$fclose( rfd );
		$finish();
        end



	// Monitor the init startup
	// 40 cycles after hs enables
	initial begin
		while( !l_txhsen ) @(negedge clk);
		for( int ii = 0; ii < 40; ii++ ) begin
			@( negedge clk );
			$display("L %16h    R %16h", l_data, r_data);
		end
	end
endmodule





module crc_tb();
	logic clk;
	logic reset;
	
	// Create clock
	initial begin
		clk = 0;
		for( ;; ) begin
			#(10ns);
			clk = !clk;
		end
	end

	// create reset
	initial begin
        $timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        // configure FST (waveform) dump
        $dumpfile("crc.fst");
        $dumpvars(1,i_dut);
		reset = 1;
		for( int ii = 0; ii < 10; ii++ ) begin
			@(negedge clk);
		end
		reset = 0;
                $display("Reset done");
		for( int ii = 0; ii < 50000; ii++ ) begin
			@(negedge clk);
		end
                $display("done");
		$finish();
	end

	// instantiate vid CRC module
	logic enable;
	logic [63:0] data;
	logic [15:0] crc;

	vid_crc i_dut(
		.reset( reset ),
		.clk( clk ),
		.en( enable ),
		.data( data ),
		.crc( crc )
	);

	// run the test
	logic [0:7][7:0] ledata; // readable data from DSI spec Annex B
	logic [23:0][7:0] test_data;
	logic [24:0][7:0] expected;
	logic [64:0][15:0][79:0] S;
	logic [64:0][79:0] D;
    	initial begin
		data = 0;
		enable = 0;
		while( reset ) @(negedge clk); // wait for reset to finish

		@(negedge clk);
		$display("crc = 0x%h", crc, );

		// test 1, line 2183 of annex B
		enable = 1;
		ledata = 64'hFF_00_00_00_1E_F0_1E_C7;
		for( int ii=0; ii < 8; ii++ ) data[ii*8+7-:8] = ledata[ii]; // dsi endian
		@(negedge clk);
		ledata = 64'h4F_82_78_C5_82_E0_8C_70;
		for( int ii=0; ii < 8; ii++ ) data[ii*8+7-:8] = ledata[ii]; // dsi endian
		@(negedge clk);
		ledata = 64'hD2_3C_78_E9_FF_00_00_01;
		for( int ii=0; ii < 8; ii++ ) data[ii*8+7-:8] = ledata[ii]; // dsi endian
		@(negedge clk);
		enable = 0;
		$display("crc = 0x%h", crc, );
		$display("test#1: %s", ( crc == 16'he569 ) ? "PASS" : "FAIL" );
		@(negedge clk);
		$display("crc = 0x%h", crc, );

		// test 2, line 2183 of annex B
		enable = 1;
		ledata = 64'hFF_00_00_02_B9_DC_F3_72;
		for( int ii=0; ii < 8; ii++ ) data[ii*8+7-:8] = ledata[ii]; // dsi endian
		@(negedge clk);
		ledata = 64'hBB_D4_B8_5A_C8_75_C2_7C;
		for( int ii=0; ii < 8; ii++ ) data[ii*8+7-:8] = ledata[ii]; // dsi endian
		@(negedge clk);
		ledata = 64'h81_F8_05_DF_FF_00_00_01;
		for( int ii=0; ii < 8; ii++ ) data[ii*8+7-:8] = ledata[ii]; // dsi endian
		@(negedge clk);
		enable = 0;
		$display("crc = 0x%h", crc, );
		$display("test#2: %s", ( crc == 16'h00F0 ) ? "PASS" : "FAIL" );
		@(negedge clk);
		$display("crc = 0x%h", crc, );

		// Test 3, line 2176
		test_data[0] = 8'h00;
		$display("CRC test: data %d, crc = %x, %s", test_data[0] , crc1( test_data[0] ), ( crc1( test_data[0] ) == { test_data[0], 16'h870F } ) ? "PASS":"FAIL" );
		test_data[0] = 8'h01;
		$display("CRC test: data %d, crc = %x, %s", test_data[0] , crc1( test_data[0] ), ( crc1( test_data[0] ) == { test_data[0], 16'h0E1E } ) ? "PASS":"FAIL" );

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

		// finish up
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
		$finish();
        end
endmodule

