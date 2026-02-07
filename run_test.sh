verilator -Wno-fatal -Wno-style -Wno-BLKANDNBLK -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-WIDTHCONCAT -Wno-ASCRANGE --binary -j 0 --timing --autoflush --trace-fst --trace-threads 2 --trace-structs --trace-depth 10 --unroll-count 1 --unroll-stmts 1 --x-assign fast --x-initial fast -O3 --top ecc_tb testbench.sv chip_top.v
obj_dir/Vecc_tb
