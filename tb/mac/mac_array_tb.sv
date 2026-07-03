// mac_array_tb.sv — Self-checking testbench for mac_array (Verilator / Icarus)

`timescale 1ns / 1ps

module mac_array_tb
    import gpu_pkg::*;
;

    logic signed [MAC_LANES-1:0][MAC_WIDTH-1:0] a;
    logic signed [MAC_LANES-1:0][MAC_WIDTH-1:0] b;
    logic                        clk;
    logic                        rst_n;
    logic                        valid;
    logic                        clear;
    logic signed [MAC_ARRAY_ACC_W-1:0] acc;
    logic                        result_valid;

    int errors;
    logic signed [MAC_ARRAY_ACC_W-1:0] expected;
    int lane;
    int idx;

    mac_array dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/mac_array_tb.vcd");
        $dumpvars(0, mac_array_tb);
    end

    task automatic wait_pipeline();
        repeat (MAC_PIPELINE_STAGES) @(posedge clk);
    endtask

    task automatic check_acc(input logic signed [MAC_ARRAY_ACC_W-1:0] exp, input string label);
        wait_pipeline();
        if (acc !== exp) begin
            $display("FAIL [%s] expected=%0d got=%0d", label, exp, acc);
            errors++;
        end else begin
            $display("PASS [%s] acc=%0d", label, acc);
        end
    endtask

    task automatic drive_chunk(input int base_idx);
        int sum;
        sum = 0;
        for (lane = 0; lane < MAC_LANES; lane++) begin
            idx = base_idx + lane;
            a[lane] = $signed(idx + 1);
            b[lane] = $signed(2 * idx + 1);
            sum = sum + a[lane] * b[lane];
        end
        valid = 1'b1;
        @(posedge clk);
        valid = 1'b0;
        expected = expected + MAC_ARRAY_ACC_W'(sum);
    endtask

    initial begin
        errors   = 0;
        expected = 0;
        rst_n    = 1'b0;
        valid    = 1'b0;
        clear    = 1'b0;

        for (lane = 0; lane < MAC_LANES; lane++) begin
            a[lane] = '0;
            b[lane] = '0;
        end

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        expected = 0;
        drive_chunk(0);
        check_acc(50, "single chunk");

        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;
        wait_pipeline();

        expected = 0;
        drive_chunk(0);
        drive_chunk(4);
        check_acc(372, "8-element dot product (2 chunks)");

        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;
        wait_pipeline();

        a[0] = -16'sd2; b[0] = 16'sd5;
        a[1] =  16'sd3; b[1] = -16'sd4;
        a[2] = -16'sd1; b[2] = -16'sd3;
        a[3] =  16'sd4; b[3] =  16'sd2;
        valid = 1'b1;
        @(posedge clk);
        valid = 1'b0;
        check_acc(-11, "signed chunk");

        repeat (4) @(posedge clk);
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===\n");
        else
            $display("\n=== %0d TEST(S) FAILED ===\n", errors);

        $finish;
    end

endmodule
