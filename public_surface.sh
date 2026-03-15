# Copy sanitized Files to public surface repo
#Chip_top.v needs sanitization
cp public_surface.sh ../CrossLink_LCD/.
#cp chip_top.v  ../CrossLink_LCD/.
awk '/MFG_START/{f=1;next}/MFG_END/{f=0;next}!f' chip_top.v > ../CrossLink_LCD/chip_top.v
git rev-parse HEAD | head -c7 > src_commit.txt
cp src_commit.txt ../CrossLink_LCD/.
cp mipi_split.png ../CrossLink_LCD/.
cp commit.mem ../CrossLink_LCD/.
cp format_commit.awk ../CrossLink_LCD/.
cp README.md  ../CrossLink_LCD/.
cp run_test.sh  ../CrossLink_LCD/.
cp testbench.sv  ../CrossLink_LCD/.
cp testgen1.sty	../CrossLink_LCD/.
cp testgen.ccl  ../CrossLink_LCD/.
cp testgen.ldc  ../CrossLink_LCD/.
cp testgen.ldf  ../CrossLink_LCD/.
cp testgen.lpf  ../CrossLink_LCD/.
cp watermark.sh ../CrossLink_LCD/.
cp dsi_dump.c ../CrossLink_LCD/.
cp left.bmp ../CrossLink_LCD/.
cp right.bmp ../CrossLink_LCD/.
cp mipi_dsi_tx/mipi_dsi_tx.v ../CrossLink_LCD/mipi_dsi_tx/.
cp user_pll/user_pll.v ../CrossLink_LCD/user_pll/.
cp BoardTestList.txt ../CrossLink_LCD/.
