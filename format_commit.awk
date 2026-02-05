# format_commit.awk - format git commit id for insttion into commit_rom.mem
# awk used to format git commmit id (stdin) into 64 lines of 8(5) binary bits of a 5x7 font:
#
# git rev-parse HEAD | head -c7 | awk -f format_commit.awk > commit.mem
#

BEGIN { # read the 7 digit commit id text input
        getline; id = $0;

	row1 = "01110_00100_01110_11110_10001_11111_01110_11111_01110_01110_01110_11110_01110_11110_11111_11111";
	row2 = "10001_01100_10001_00001_10001_10000_10001_00001_10001_10001_10001_10001_10001_10001_10000_10000";
	row3 = "10011_00100_00001_00001_10001_10000_10000_00001_10001_10001_10001_10001_10000_10001_10000_10000";
	row4 = "10101_00100_00010_01110_11111_11110_11110_00010_01110_01111_10001_11110_10000_10001_11110_11110";
	row5 = "11001_00100_00100_00001_00001_00001_10001_00100_10001_00001_11111_10001_10000_10001_10000_10000";
	row6 = "10001_00100_01000_00001_00001_00001_10001_00100_10001_10001_10001_10001_10001_10001_10000_10000";
	row7 = "01110_01110_11111_11110_00001_11110_01110_00100_01110_01110_10001_11110_01110_11110_11111_10000";
	row8 = "00000_00001_00010_00011_00100_00101_00110_00111_01000_01001_01010_01011_01100_01101_01110_01111";

        # format them for a mif file substiturion
	for( ii = 1; ii <= 7; ii++ ) {
		switch( substr( id, ii, 1 ) ) {
			case "0" : ofs = 0*6+1; break;
			case "1" : ofs = 1*6+1; break;
			case "2" : ofs = 2*6+1;; break;
			case "3" : ofs = 3*6+1;; break;
			case "4" : ofs = 4*6+1;; break;
			case "5" : ofs = 5*6+1;; break;
			case "6" : ofs = 6*6+1;; break;
			case "7" : ofs = 7*6+1;; break;
			case "8" : ofs = 8*6+1;; break;
			case "9" : ofs = 9*6+1;; break;
			case "a" : ofs = 10*6+1; break;
			case "b" : ofs = 11*6+1; break;
			case "c" : ofs = 12*6+1; break;
			case "d" : ofs = 13*6+1; break;
			case "e" : ofs = 14*6+1; break;
			case "f" : ofs = 15*6+1; break;
		}
		print "000" substr(row1, ofs, 5)
		print "000" substr(row2, ofs, 5)
		print "000" substr(row3, ofs, 5)
		print "000" substr(row4, ofs, 5)
		print "000" substr(row5, ofs, 5)
		print "000" substr(row6, ofs, 5)
		print "000" substr(row7, ofs, 5)
		print "000" substr(row8, ofs, 5)
	}
	for( ii = 0; ii < 8; ii++ ) {
		print "00000000"
	}
}
