# CrossLink_LCD
Lattice FPGA verilog design using a CrossLink device MIPI D-PHY cores for 8gbps 2x4lane LCD display
This repo contains the public surface of a design targetting a custom LCD display.

The Lattice crosslink fpga's are tergetted at video bridging of module image sensors and display. 
Lattice's Diamond design software provides free tools for verilog synthesis, place and route.
Showcasing two hardened 4-lane MIPI D-PHY interfaces, and 5936x Lut4s and 16x 9kbit block rams , alot can be packed in here. 

This design is an interface to a custom LCD module use a 2x4Lane interface that supports 1800x1800 at 100Hz of RGB24 without compression.
It is a custom design done from-scratch as low-level verilog design. It directly instantiating the FPGA's MIPI D-PHYs and emits an RGB image of a Smpte style color-bar test pattern.
The design includes video sync generation, RGB888 test pattern generation with text overlay, MIPI DSI LCD intialization and video stream generation, and integration on a dev board.   

![floorplan](Screenshot%202026-01-31%20143339.png "Crossfire floorplan")

The floorplan shows the crossfire device with a design snapshot with 55% utillzation. The two MIPI D-PHYs are the blocks at the top, and the 16 block rams are shown across the middle
The array of FPGA LAB each contain 4 Luts with flipflops. 

I use a commit ROM on all my fpga video designs is used to insert the git commit id7 into a memory rom to be overlayed as text on the video. The aids debug by directly connting video effects and display with git commit version. A simple photo then becomes an powerful debug artefact. The watermark script is run after git clone/pull/checkout, before the fpga build. The script puts the 7 hex digit commit id7 into a rom initiazation file. This way the synthesis results do not change from the build that commmit was associated with (re-builds are not guaranteed identical if the source code is changes, but you can change a ROM's contents). For this design I actually render the 7 hex digits as a 5x7 font into the rom with the script. It is expanded to 7x14 on display overlay.

The design configures the MIPI blocks as 16:1, so in HS mode 64bits are sent to each mipi block, each cycle, at 62.5Mhz. For RGB888 this gives 8 pixels every 3 cycles. For convenience RGB data is formatted as 4 pels of RRGB88 per cycle per lane every 2 of 3 cycles (2:3 phase style clock crossing). A simple RGB frame generator takes in video sync singels and generates the X, Y addresses and logic to generate a RGB test pattern. The RGB test pattern generator is instantiated 8 times to generate 4 pels at differnt X locations for each of the 2 lanes. 

Hardware debug often involves observing LEDs. For FPGA projects where the logic controls the display pixels you can treat the display pixels as LEDs and use them to directly display live FPGA state.
A little bit of logic tiles 5x7(7x14) font characters over the image by ORing into the video logic can display test and is used to dump live hexadecimal values such as performance measurements, counters or state. I use this alot to quickly debug fpga logic. It may be useful in this case, so it was a tool I added at the begining. Unlike a rom based font, this logic grows linearly with the number of characters displayed, and can get quite large, so as the chip fills up with intended logic, this is the first logic to be turned off. I use a single Verilog OR(|) statement to control which strings are overlayed as White on the video. This allows quickly turning off a line of text and the synthesis tool will prune the logic, allowed to keep the debug statements in place for future use when need.
