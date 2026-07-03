// mac_unit_gls_tb.sv — Gate-level simulation (post-Yosys netlist + simlib)
// Extra pipeline margin accounts for techmap multiplier depth vs RTL.

`timescale 1ns / 1ps

module mac_unit_gls_tb;

    localparam int WIDTH = 16;
    localparam int ACC_W = 32;
    localparam int PIPE_STAGES = 2;
    localparam int PIPE_MARGIN = 2;  // additional cycles for gate-level delay

    logic             clk;
    logic             rst_n;
    logic             valid;
    logic             clear;
    logic signed [WIDTH-1:0] a;
    logic signed [WIDTH-1:0] b;
    wire  signed [ACC_W-1:0] acc;
    wire                     acc_valid;

    int errors;

    mac_unit dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid     (valid),
        .clear     (clear),
        .a         (a),
        .b         (b),
        .acc       (acc),
        .acc_valid (acc_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic wait_result();
        repeat (PIPE_STAGES + PIPE_MARGIN) @(posedge clk);
        #1;
    endtask

    task automatic check_acc(input int exp, input string label);
        wait_result();
        if (acc !== ACC_W'(exp)) begin
            $display("FAIL [%s] expected=%0d got=%0d", label, exp, acc);
            errors++;
        end else begin
            $display("PASS [%s] acc=%0d", label, exp);
        end
    endtask

    initial begin
        errors = 0;
        rst_n  = 1'b0;
        valid  = 1'b0;
        clear  = 1'b0;
        a      = '0;
        b      = '0;

        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

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
        wait_result();
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

        begin : dot8
            int i;
            int expected;
            expected = 0;
            for (i = 0; i < 8; i++) begin
                valid = 1'b1;
                a     = 16'(i + 1);
                b     = 16'(2 * i + 1);
                expected = expected + (i + 1) * (2 * i + 1);
                @(posedge clk);
            end
            valid = 1'b0;
            check_acc(expected, "8-element dot product");
        end

        if (errors == 0)
            $display("\n=== GATE-LEVEL ALL TESTS PASSED ===\n");
        else
            $display("\n=== GATE-LEVEL %0d TEST(S) FAILED ===\n", errors);

        $finish;
    end

endmodule
