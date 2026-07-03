// sram_tb.sv — Basic SRAM read/write test

`timescale 1ns / 1ps

module sram_tb;

    localparam int DEPTH = 16;
    localparam int WIDTH = 16;
    localparam int ADDR_W = 4;

    logic clk;
    logic wen;
    logic [ADDR_W-1:0] addr;
    logic signed [WIDTH-1:0] wdata;
    logic signed [WIDTH-1:0] rdata;

    int errors;
    int i;

    sync_sram #(
        .DEPTH  (DEPTH),
        .WIDTH  (WIDTH),
        .ADDR_W (ADDR_W)
    ) dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/sram_tb.vcd");
        $dumpvars(0, sram_tb);
    end

    task automatic write_word(input int a, input int d);
        @(posedge clk);
        addr  <= ADDR_W'(a);
        wdata <= WIDTH'(d);
        wen   <= 1'b1;
        @(posedge clk);
        wen <= 1'b0;
    endtask

    task automatic check_read(input int a, input int exp, input string label);
        addr = ADDR_W'(a);
        @(posedge clk);
        if (rdata !== WIDTH'(exp)) begin
            $display("FAIL [%s] addr=%0d expected=%0d got=%0d", label, a, exp, rdata);
            errors++;
        end else begin
            $display("PASS [%s] addr=%0d data=%0d", label, a, rdata);
        end
    endtask

    initial begin
        errors = 0;
        wen    = 1'b0;
        addr   = '0;
        wdata  = '0;

        repeat (2) @(posedge clk);

        $display("=== SRAM write/read test ===");
        for (i = 0; i < DEPTH; i++)
            write_word(i, (i + 1) * 3);

        for (i = 0; i < DEPTH; i++)
            check_read(i, (i + 1) * 3, "readback");

        write_word(3, 999);
        check_read(3, 999, "overwrite");
        check_read(2, 9, "neighbor intact");

        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===\n");
        else
            $display("\n=== %0d TEST(S) FAILED ===\n", errors);

        $finish;
    end

endmodule
