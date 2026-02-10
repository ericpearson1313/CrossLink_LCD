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
		for( int ii = 0; ii < 150*62500; ii++ ) begin // 100 ms
			@(negedge clk);
		end
                $display("Test terminated, exceeded MY time line");
		$finish();
	end

	// instantiate DUT

	logic lcd_reset, lcd_pn2ptx, lcd_en_vsp, lcd_en_vsn, lcd_en_vcc;
	logic d0_txlpen, d0_txlpn, d0_txlpp, d0_txhsen;
	wire clk_txlpen, clk_txlpn, clk_txlpp;
	wire clk_txhsen, clk_txhsgate;
	logic [63:0] a_tx_data, b_tx_data;
	logic [95:0] left_rgb, right_rgb;
	logic vsync, hsync, active;
	logic [2:0] phase;
	logic [3:0] ovl;
	mipi_format_lcd i_dut(
		// System
		.clk	( clk ),
		.reset	( reset ),
		// LCD Info inputs
		.lcd_te( 1'b1 ),
		.lcd_pwm( 1'b0 ),
		.lcd_id( 2'b01 ),
		// LCD control outputs
		.lcd_reset( lcd_reset ),
		.lcd_pn2ptx( lcd_pn2ptx ),
		.lcd_en_vsp( lcd_en_vsp ),
		.lcd_en_vsn( lcd_en_vsn ),
		.lcd_en_vcc( lcd_en_vcc ),
		// Mipi Control Outputs
		.txlpen	( d0_txlpen ),
		.txlpn	( d0_txlpn ),
		.txlpp	( d0_txlpp ),
		.txhsen	( d0_txhsen ),
		.clk_txhsen	( clk_txhsen ), 
		.clk_txhsgate	( clk_txhsgate ), 
		.clk_txlpen	( clk_txlpen ), 
    		.clk_txlpn 	( clk_txlpn ), 
		.clk_txlpp	( clk_txlpp ),
		// Mipi Tx Data
		.l_data ( a_tx_data[63:0] ),
		.r_data ( b_tx_data[63:0] ),
		// Video Sync output
		.vsync ( vsync ),
		.hsync ( hsync ),
		.active( active ),
		.phase ( phase[2:0] ),
		// RGB Inputs
		.l_rgb	( left_rgb[95:0] ),
		.r_rgb	( right_rgb[95:0] | {{24{ovl[3]}},{24{ovl[2]}},{24{ovl[1]}},{24{ovl[0]}}}  )
	);

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

	wire blink;
	// speed up blink so it finishes in sime time
	commit_overlay #(22) i_com_ovl( clk, reset, vsync, hsync, active, phase, ovl, blink); 

	// Run the test
    	initial begin
		left_rgb = 96'h01234567_89abcdef_76543210;
		right_rgb = 96'h89abcdef_01234567_89abcdef;
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
		$finish();
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

