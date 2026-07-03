// vau_tb.sv — Vector Activation Unit testbench

`timescale 1ns / 1ps

module vau_tb
    import gpu_pkg::*;
    import act_pkg::*;
;

    localparam int ACC_W = SYSTOLIC_ACC_W;
    localparam int WIDTH = SYSTOLIC_WIDTH;

    logic clk;
    logic rst_n;
    logic valid_in;
    logic [1:0] act_mode;
    logic signed [ACC_W-1:0] data_in;
    logic valid_out;
    logic signed [WIDTH-1:0] data_out;

    int errors;
    int cycles;
    int got;

    vau #(
        .ACC_W   (ACC_W),
        .OUT_W   (WIDTH),
        .LATENCY (VAU_LATENCY)
    ) dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/vau_tb.vcd");
        $dumpvars(0, vau_tb);
    end

    task automatic drive_and_check(
        input int acc_q16,
        input int mode,
        input int exp_min,
        input int exp_max,
        input string label
    );
        int guard;
        cycles = 0;
        @(posedge clk);
        valid_in <= 1'b1;
        act_mode <= mode[1:0];
        data_in  <= ACC_W'(acc_q16);
        @(posedge clk);
        valid_in <= 1'b0;

        guard = 0;
        got = 0;
        while (!valid_out && guard < 10) begin
            @(posedge clk);
            guard++;
        end
        if (!valid_out) begin
            $display("FAIL [%s] no valid_out", label);
            errors++;
        end else begin
            got = data_out;
            if (got < exp_min || got > exp_max) begin
                $display("FAIL [%s] acc=%0d mode=%0d got=%0d expected [%0d..%0d]",
                         label, acc_q16, mode, got, exp_min, exp_max);
                errors++;
            end else begin
                $display("PASS [%s] got=%0d", label, got);
            end
        end
        repeat (2) @(posedge clk);
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        valid_in = 1'b0;
        act_mode = ACT_RELU;
        data_in = '0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("=== VAU activation tests ===");
        drive_and_check(5, ACT_RELU, 5, 5, "ReLU positive");
        drive_and_check(-3, ACT_RELU, 0, 0, "ReLU negative");
        drive_and_check(0, ACT_GELU, -1, 1, "GeLU near zero");
        drive_and_check(2, ACT_GELU, 1, 3, "GeLU positive");
        drive_and_check(-2, ACT_SILU, -2, 0, "SiLU negative");
        drive_and_check(3, ACT_SILU, 2, 4, "SiLU positive");

        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===\n");
        else
            $display("\n=== %0d TEST(S) FAILED ===\n", errors);

        $finish;
    end

endmodule
