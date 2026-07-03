// shader_core_tb.sv — End-to-end shader core test (2 warps, dot product)

`timescale 1ns / 1ps

module shader_core_tb
    import gpu_pkg::*;
;

    logic clk;
    logic rst_n;
    logic start;
    logic done;
    logic signed [MAC_ARRAY_ACC_W-1:0] warp_acc_0;
    logic signed [MAC_ARRAY_ACC_W-1:0] warp_acc_1;

    int errors;
    int cycles;

    shader_core #(
        .NUM_WARPS (NUM_WARPS)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .done       (done),
        .warp_acc_0 (warp_acc_0),
        .warp_acc_1 (warp_acc_1)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/shader_core_tb.vcd");
        $dumpvars(0, shader_core_tb);
    end

    task automatic wait_done();
        cycles = 0;
        while (!done && cycles < 500) begin
            @(posedge clk);
            cycles++;
        end
    endtask

    initial begin
        errors = 0;
        rst_n  = 1'b0;
        start  = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait_done();

        if (cycles >= 500) begin
            $display("FAIL [timeout] shader core did not finish");
            errors++;
        end

        @(posedge clk);  // let warp_acc NBA captures settle

        if (warp_acc_0 !== 372) begin
            $display("FAIL [warp0] expected=372 got=%0d", warp_acc_0);
            errors++;
        end else begin
            $display("PASS [warp0] acc=%0d", warp_acc_0);
        end

        if (warp_acc_1 !== 8) begin
            $display("FAIL [warp1] expected=8 got=%0d", warp_acc_1);
            errors++;
        end else begin
            $display("PASS [warp1] acc=%0d", warp_acc_1);
        end

        repeat (4) @(posedge clk);
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===\n");
        else
            $display("\n=== %0d TEST(S) FAILED ===\n", errors);

        $finish;
    end

endmodule
