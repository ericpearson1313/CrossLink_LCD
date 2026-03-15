verilator -Wno-fatal -Wno-style -Wno-BLKANDNBLK -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-WIDTHCONCAT -Wno-ASCRANGE --binary -j 0 --timing --autoflush --trace-fst --trace-threads 2 --trace-structs --trace-depth 10 --unroll-count 1 --unroll-stmts 1 --x-assign fast --x-initial fast -O3 --top dsi_tb testbench.sv chip_top.v -DSIM
obj_dir/Vdsi_tb
cc dsi_dump.c -o dsi_dump
./dsi_dump < left.dsi > file
mv -f dsi.bmp left.bmp
./dsi_dump < right.dsi > file
mv -f dsi.bmp right.bmp
