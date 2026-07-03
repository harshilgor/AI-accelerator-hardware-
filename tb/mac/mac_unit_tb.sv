// mac_unit_tb.sv — Self-checking testbench for mac_unit (Verilator / Icarus)

`timescale 1ns / 1ps

module mac_unit_tb
    import gpu_pkg::*;
;

    localparam int ACC_W = MAC_ACC_W;

    logic                        clk;
    logic                        rst_n;
    logic                        valid;
    logic                        clear;
    logic signed [MAC_WIDTH-1:0] a;
    logic signed [MAC_WIDTH-1:0] b;
    logic signed [ACC_W-1:0]     acc;
    logic                        acc_valid;

    int errors;
    int expected;
    int i;

    mac_unit dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/mac_unit_tb.vcd");
        $dumpvars(0, mac_unit_tb);
    end

    task automatic wait_pipeline();
        repeat (MAC_PIPELINE_STAGES) @(posedge clk);
    endtask

    task automatic check_acc(input int exp, input string label);
        wait_pipeline();
        if (acc !== exp) begin
            $display("FAIL [%s] expected=%0d got=%0d", label, exp, acc);
            errors++;
        end else begin
            $display("PASS [%s] acc=%0d", label, acc);
        end
    endtask

    initial begin
        errors = 0;
        rst_n  = 1'b0;
        valid  = 1'b0;
        clear  = 1'b0;
        a      = '0;
        b      = '0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        valid = 1'b1;
        a     = 16'sd3;
        b     = 16'sd4;
        @(posedge clk);
        valid = 1'b0;
        check_acc(12, "single MAC 3*4");

        valid = 1'b1;
        a     = 16'sd2;
        b     = 16'sd5;
        @(posedge clk);
        a     = 16'sd1;
        b     = 16'sd7;
        @(posedge clk);
        a     = 16'sd4;
        b     = 16'sd3;
        @(posedge clk);
        valid = 1'b0;
        check_acc(41, "accumulate chain");

        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;
        wait_pipeline();
        if (acc !== 0) begin
            $display("FAIL [clear] expected=0 got=%0d", acc);
            errors++;
        end else begin
            $display("PASS [clear] acc=0");
        end

        valid = 1'b1;
        a     = -16'sd3;
        b     = 16'sd4;
        @(posedge clk);
        valid = 1'b0;
        check_acc(-12, "signed negative a");

        valid = 1'b1;
        a     = -16'sd2;
        b     = -16'sd5;
        @(posedge clk);
        valid = 1'b0;
        check_acc(-2, "signed both negative");

        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;
        @(posedge clk);

        expected = 0;
        for (i = 0; i < 8; i++) begin
            valid = 1'b1;
            a     = 16'(i + 1);
            b     = 16'(2 * i + 1);
            expected = expected + a * b;
            @(posedge clk);
        end
        valid = 1'b0;
        check_acc(expected, "8-element dot product");

        repeat (4) @(posedge clk);
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===\n");
        else
            $display("\n=== %0d TEST(S) FAILED ===\n", errors);

        $finish;
    end

endmodule
