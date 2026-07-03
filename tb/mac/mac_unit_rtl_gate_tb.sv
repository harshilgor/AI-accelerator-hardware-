// mac_unit_rtl_gate_tb.sv — RTL vs Yosys netlist equivalence cosim (Phase 4)
// Golden checks run on RTL; gate netlist must match RTL sample (not Icarus golden alone).

`timescale 1ns / 1ps

module mac_unit_rtl_gate_tb;

    localparam int WIDTH = 16;
    localparam int ACC_W = 32;
    localparam int LATENCY = 4;

    logic             clk;
    logic             rst_n;
    logic             valid;
    logic             clear;
    logic signed [WIDTH-1:0] a;
    logic signed [WIDTH-1:0] b;

    logic signed [ACC_W-1:0] rtl_acc;
    logic signed [ACC_W-1:0] gate_acc;

    int errors;

    mac_unit rtl_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid     (valid),
        .clear     (clear),
        .a         (a),
        .b         (b),
        .acc       (rtl_acc),
        .acc_valid ()
    );

    mac_unit_gate gate_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid     (valid),
        .clear     (clear),
        .a         (a),
        .b         (b),
        .acc       (gate_acc),
        .acc_valid ()
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic sample_both(
        output logic signed [ACC_W-1:0] rtl_s,
        output logic signed [ACC_W-1:0] gate_s
    );
        repeat (LATENCY) @(posedge clk);
        #1;
        rtl_s  = rtl_acc;
        gate_s = gate_acc;
    endtask

    task automatic check_equiv(input int exp, input string label);
        logic signed [ACC_W-1:0] rtl_s, gate_s;
        sample_both(rtl_s, gate_s);
        if (rtl_s !== ACC_W'(exp)) begin
            $display("FAIL RTL  [%s] expected=%0d got=%0d", label, exp, rtl_s);
            errors++;
        end
        if (gate_s !== rtl_s) begin
            $display("FAIL GATE [%s] rtl=%0d gate=%0d (mismatch)", label, rtl_s, gate_s);
            errors++;
        end else if (rtl_s === ACC_W'(exp)) begin
            $display("PASS [%s] rtl=gate=%0d", label, rtl_s);
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
        check_equiv(12, "single MAC 3*4");

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
        check_equiv(41, "accumulate chain");

        clear = 1'b1;
        @(posedge clk);
        clear = 1'b0;
        check_equiv(0, "clear");

        valid = 1'b1;
        a     = -16'sd3;
        b     = 16'sd4;
        @(posedge clk);
        valid = 1'b0;
        check_equiv(-12, "signed negative a");

        valid = 1'b1;
        a     = -16'sd2;
        b     = -16'sd5;
        @(posedge clk);
        valid = 1'b0;
        check_equiv(-2, "signed both negative");

        if (errors == 0)
            $display("\n=== RTL/GATE COSIM EQUIV PASSED ===\n");
        else begin
            $display("\n=== RTL/GATE COSIM EQUIV FAILED (%0d) ===\n", errors);
            $fatal(1, "RTL/gate cosim mismatch");
        end

        $finish;
    end

endmodule
